//
//  AuthManager.swift
//  KeepTheBudget
//
//  Handles OAuth 2.0 authentication with Microsoft using interactive flow
//

import Foundation
import MSAL

enum AuthError: LocalizedError {
    case missingConfiguration(String)
    case notInitialized
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let msg):
            return "Configuration Error: \(msg)"
        case .notInitialized:
            return "AuthManager not initialized"
        case .sessionExpired:
            return "Session expired - no account available"
        }
    }
}

class AuthManager {
    private let storageManager: StorageManager
    private var msalApplication: MSALPublicClientApplication?
    private var authority: MSALAuthority?
    private var clientId: String?
    private var tenantId: String?

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
        // Don't call setupMSAL here anymore - it will be called in initialize()
    }

    // MARK: - Initialization

    /// Initialize AuthManager with configuration from Keychain
    /// Must be called before any authentication operations
    ///
    /// - Parameters:
    ///   - clientId: Pre-loaded Client ID (optional, loads from storage if nil)
    ///   - tenantId: Pre-loaded Tenant ID (optional, loads from storage if nil)
    func initialize(clientId: String? = nil, tenantId: String? = nil) throws {
        // Use provided values or load from storage
        let finalClientId: String
        let finalTenantId: String

        if let providedClientId = clientId, let providedTenantId = tenantId {
            print("🔧 Using pre-loaded configuration")
            finalClientId = providedClientId
            finalTenantId = providedTenantId
        } else {
            print("🔧 Loading configuration from storage")
            guard let loadedClientId = storageManager.loadClientId() else {
                throw AuthError.missingConfiguration("Client ID not configured")
            }

            guard let loadedTenantId = storageManager.loadTenantId() else {
                throw AuthError.missingConfiguration("Tenant ID not configured")
            }

            finalClientId = loadedClientId
            finalTenantId = loadedTenantId
        }

        self.clientId = finalClientId
        self.tenantId = finalTenantId

        let authorityURL = "https://login.microsoftonline.com/\(finalTenantId)"
        self.authority = try MSALAuthority(url: URL(string: authorityURL)!)

        print("🔧 Initializing AuthManager with:")
        print("   Client ID: \(finalClientId)")
        print("   Tenant ID: \(finalTenantId)")

        try setupMSAL()
    }

    /// Check if AuthManager is initialized and ready to use
    func isInitialized() -> Bool {
        return msalApplication != nil
    }

    private func setupMSAL() throws {
        guard let clientId = self.clientId else {
            throw AuthError.missingConfiguration("Client ID not loaded")
        }

        guard let authority = self.authority else {
            throw AuthError.missingConfiguration("Authority not configured")
        }

        // Use MSAL standard redirect URI format
        let redirectUri = "msal\(clientId)://auth"

        // Validate against Info.plist
        validateRedirectURI(redirectUri)

        print("   Redirect URI: \(redirectUri)")

        let config = MSALPublicClientApplicationConfig(clientId: clientId, redirectUri: redirectUri, authority: authority)

        // Log cache configuration
        print("   MSAL cache keychain group: \(config.cacheConfig.keychainSharingGroup ?? "(default - app's keychain)")")

        msalApplication = try MSALPublicClientApplication(configuration: config)

        // Log MSAL cache status after initialization
        if let app = msalApplication {
            do {
                let accounts = try app.allAccounts()
                print("   MSAL cache has \(accounts.count) persisted account(s)")
            } catch {
                print("   ⚠️  Could not read MSAL cache: \(error)")
            }
        }

        print("✅ MSAL initialized successfully")
    }

    private func validateRedirectURI(_ redirectUri: String) {
        // Check if Info.plist contains this scheme
        if let plistClientId = ConfigurationValidator.extractClientIdFromInfoPlist() {
            let expectedRedirect = "msal\(plistClientId)://auth"
            if redirectUri != expectedRedirect {
                print("⚠️  WARNING: Redirect URI mismatch")
                print("⚠️  Configured: \(redirectUri)")
                print("⚠️  Info.plist: \(expectedRedirect)")
                print("⚠️  Authentication may fail")
            }
        }
    }

    // MARK: - Token Management

    func hasValidTokens() -> Bool {
        guard isInitialized() else {
            print("      hasValidTokens: not initialized")
            return false
        }

        guard let _ = storageManager.loadAccessToken() else {
            print("      hasValidTokens: no access token")
            return false
        }

        guard let expiry = storageManager.loadTokenExpiry() else {
            print("      hasValidTokens: no expiry date")
            return false
        }

        let timeRemaining = expiry.timeIntervalSinceNow
        print("      hasValidTokens: token expires in \(timeRemaining) seconds")

        // Check if token expires within next 1 minute (proactive refresh handles the rest)
        return timeRemaining > 60
    }

    /// Check if token should be proactively refreshed before expiration
    /// Returns true if token expires within 45 minutes (75% of typical 60-min lifetime)
    func shouldProactivelyRefresh() -> Bool {
        guard let expiry = storageManager.loadTokenExpiry() else {
            print("   ⚠️  No token expiry - cannot determine refresh need")
            return false
        }

        let timeRemaining = expiry.timeIntervalSinceNow

        // Urgent: Token expired or expires within 5 minutes
        if timeRemaining < 300 {
            print("🚨 Token URGENT: expires in \(Int(timeRemaining))s")
            return true
        }

        // Proactive: Refresh when < 45 minutes remain (75% through 60-min token lifetime)
        // This gives us multiple chances to refresh before expiration
        let refreshThreshold: TimeInterval = 2700  // 45 minutes (was 30)

        if timeRemaining < refreshThreshold {
            print("ℹ️  Token expires in \(Int(timeRemaining/60))m - proactive refresh recommended")
            return true
        }

        return false
    }

    /// Perform proactive token refresh without requiring user interaction
    /// Safe to call periodically in background - only refreshes if needed
    func proactiveTokenRefresh() async {
        print("🔄 Proactive token refresh check")

        guard isInitialized() else {
            print("   ⏭️  Not initialized, skipping")
            return
        }

        // Always log token status for debugging
        if let expiry = storageManager.loadTokenExpiry() {
            let minutesRemaining = Int(expiry.timeIntervalSinceNow / 60)
            print("   📊 Current token status: \(minutesRemaining) minutes remaining")
        } else {
            print("   ⚠️  No token expiry found")
        }

        guard shouldProactivelyRefresh() else {
            if let expiry = storageManager.loadTokenExpiry() {
                let minutesRemaining = Int(expiry.timeIntervalSinceNow / 60)
                print("   ✅ Token valid for \(minutesRemaining)m, no refresh needed")
            }
            return
        }

        print("   🔄 Starting proactive refresh...")

        // Check if MSAL has accounts cached
        if let application = msalApplication {
            do {
                let accounts = try application.allAccounts()
                print("   📋 MSAL cache has \(accounts.count) account(s)")
                if accounts.isEmpty {
                    print("   ❌ CRITICAL: MSAL cache empty - cannot refresh silently!")
                    print("   💡 User will need to re-authenticate on next API call")
                    return
                }
            } catch {
                print("   ❌ Failed to check MSAL accounts: \(error)")
                return
            }
        }

        do {
            _ = try await refreshAccessToken()
            print("   ✅ Proactive refresh successful")
        } catch {
            print("   ❌ CRITICAL: Proactive refresh FAILED!")
            print("   Error: \(error.localizedDescription)")
            print("   Error type: \(type(of: error))")
            if let authError = error as? AuthError {
                print("   AuthError: \(authError)")
            }
            // Don't throw - but this will cause re-auth on next API call
        }
    }

    /// Log current token status for debugging
    func logTokenStatus() {
        print("🔍 Token Status:")
        print("   Access token: \(storageManager.loadAccessToken() != nil ? "present" : "missing")")
        print("   MSAL cache: \(isInitialized() ? "initialized" : "not initialized")")

        if let expiry = storageManager.loadTokenExpiry() {
            let timeRemaining = expiry.timeIntervalSinceNow
            let minutesRemaining = Int(timeRemaining / 60)

            if timeRemaining > 0 {
                print("   Expiry: in \(minutesRemaining) minutes")
            } else {
                print("   Expiry: EXPIRED \(-minutesRemaining) minutes ago")
            }
        } else {
            print("   Expiry: not set")
        }
    }

    func getValidAccessToken() async throws -> String {
        print("   🔍 getValidAccessToken() called")

        guard isInitialized() else {
            print("   ❌ Not initialized!")
            throw AuthError.notInitialized
        }
        print("   ✅ Is initialized")

        // Check if current token is still valid
        let hasTokens = hasValidTokens()
        print("   Has valid tokens: \(hasTokens)")

        if hasTokens, let token = storageManager.loadAccessToken() {
            print("   ✅ Returning cached token")
            return token
        }

        // Try to refresh the token
        print("   🔄 Attempting token refresh...")
        do {
            return try await refreshAccessToken()
        } catch {
            print("   ❌ getValidAccessToken: refreshAccessToken threw error")
            print("       Error type: \(type(of: error))")
            print("       Error: \(error)")
            throw error
        }
    }

    /// Invalidate cached token to force refresh
    func invalidateCachedToken() {
        print("🔄 Invalidating cached token")
        storageManager.deleteAllTokens()
    }

    /// Force token refresh, bypassing validity check
    /// Used when HTTP 401 received to attempt recovery
    func forceTokenRefresh() async throws -> String {
        print("🔄 Force token refresh requested")

        guard isInitialized() else {
            print("   ❌ Not initialized!")
            throw AuthError.notInitialized
        }

        // Invalidate cached token first
        invalidateCachedToken()

        // Attempt silent refresh
        do {
            let token = try await refreshAccessToken()
            print("✅ Force refresh successful")
            return token
        } catch {
            print("❌ Force refresh failed: \(error.localizedDescription)")

            // Interpret MSAL error codes
            let nsError = error as NSError
            print("   Error domain: \(nsError.domain)")
            print("   Error code: \(nsError.code)")

            if nsError.domain == "MSALErrorDomain" {
                switch nsError.code {
                case -42001:
                    print("   → User interaction required (re-authentication needed)")
                case -42002:
                    print("   → Server declined scopes")
                case -42003:
                    print("   → Invalid grant (token revoked)")
                default:
                    print("   → MSAL error code: \(nsError.code)")
                }
            }

            throw error
        }
    }

    // MARK: - Interactive Authentication

    func startInteractiveAuth(parentWindow: NSWindow? = nil) async throws -> String {
        guard isInitialized() else {
            throw AuthError.notInitialized
        }

        print("🔐 Starting interactive authentication...")

        guard let application = msalApplication else {
            print("❌ MSAL application not initialized!")
            throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "MSAL not initialized"])
        }

        print("✅ MSAL application is initialized")
        print("📋 Scopes: \(GraphConstants.scopes)")

        // On macOS, MSAL uses the system browser, so no parent window is needed
        let webviewParameters = MSALWebviewParameters()
        webviewParameters.webviewType = .default
        let interactiveParameters = MSALInteractiveTokenParameters(scopes: GraphConstants.scopes, webviewParameters: webviewParameters)

        print("🌐 Webview type: \(webviewParameters.webviewType.rawValue)")
        print("🚀 Calling acquireToken...")

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireToken(with: interactiveParameters) { (result, error) in
                if let error = error {
                    print("❌ Authentication error: \(error)")
                    print("   Error domain: \((error as NSError).domain)")
                    print("   Error code: \((error as NSError).code)")
                    print("   Error description: \(error.localizedDescription)")
                    print("   User info: \((error as NSError).userInfo)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else {
                    print("❌ No result received from MSAL")
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "No result received"]))
                    return
                }

                print("✅ Authentication successful!")
                print("   Access token received (length: \(result.accessToken.count))")

                // Save tokens
                let accessToken = result.accessToken
                let expiry = result.expiresOn ?? Date().addingTimeInterval(3600) // Default to 1 hour from now

                // Save access token and expiry
                // Note: MSAL manages refresh tokens internally - we don't have access to them
                _ = self.storageManager.saveAccessToken(accessToken)
                _ = self.storageManager.saveTokenExpiry(expiry)

                print("✅ Tokens saved (MSAL manages refresh token internally)")

                continuation.resume(returning: accessToken)
            }
        }
    }

    // MARK: - Silent Token Refresh

    private func refreshAccessToken() async throws -> String {
        print("   🔍 refreshAccessToken() called")

        guard isInitialized() else {
            print("   ❌ Not initialized!")
            throw AuthError.notInitialized
        }

        guard let application = msalApplication else {
            print("   ❌ MSAL application is nil!")
            throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "MSAL not initialized"])
        }

        // Try to get cached account
        print("   📋 Getting cached accounts...")
        let accounts = try application.allAccounts()
        print("   Found \(accounts.count) accounts")

        if accounts.isEmpty {
            print("   ℹ️  No account in MSAL cache - session expired")
            print("   🔐 Throwing AuthError.sessionExpired")
            throw AuthError.sessionExpired
        }

        guard let account = accounts.first else {
            print("   ❌ No account found!")
            throw AuthError.sessionExpired
        }

        print("   ✅ Using account: \(account.username ?? "unknown")")
        let parameters = MSALSilentTokenParameters(scopes: GraphConstants.scopes, account: account)
        print("   🔄 Calling acquireTokenSilent...")

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireTokenSilent(with: parameters) { (result, error) in
                if let error = error {
                    print("   ❌ Silent refresh failed")
                    let nsError = error as NSError
                    print("   Error domain: \(nsError.domain)")
                    print("   Error code: \(nsError.code)")
                    print("   Error description: \(error.localizedDescription)")
                    print("   User info: \(nsError.userInfo)")

                    // Interpret common MSAL errors
                    if nsError.domain == "MSALErrorDomain" {
                        switch nsError.code {
                        case -42001:
                            print("   → User interaction required (re-authentication needed)")
                        case -42002:
                            print("   → Server declined scopes")
                        case -42003:
                            print("   → Invalid grant (token revoked)")
                        default:
                            break
                        }
                    }

                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else {
                    print("   ❌ No result from silent refresh")
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "No result from silent refresh"]))
                    return
                }

                print("   ✅ Silent refresh successful")

                // Update stored tokens
                let accessToken = result.accessToken
                let expiry = result.expiresOn ?? Date().addingTimeInterval(3600) // Default to 1 hour from now

                // Save access token and expiry
                // Note: MSAL manages refresh tokens internally
                _ = self.storageManager.saveAccessToken(accessToken)
                _ = self.storageManager.saveTokenExpiry(expiry)

                continuation.resume(returning: accessToken)
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        storageManager.deleteAllTokens()

        // Remove account from MSAL cache
        if let application = msalApplication {
            do {
                let accounts = try application.allAccounts()
                for account in accounts {
                    try application.remove(account)
                }
            } catch {
                print("Failed to remove accounts: \(error)")
            }
        }
    }
}
