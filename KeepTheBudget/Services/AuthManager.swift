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

    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let msg):
            return "Configuration Error: \(msg)"
        case .notInitialized:
            return "AuthManager not initialized"
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
    func initialize() throws {
        guard let clientId = storageManager.loadClientId() else {
            throw AuthError.missingConfiguration("Client ID not configured")
        }

        guard let tenantId = storageManager.loadTenantId() else {
            throw AuthError.missingConfiguration("Tenant ID not configured")
        }

        self.clientId = clientId
        self.tenantId = tenantId

        let authorityURL = "https://login.microsoftonline.com/\(tenantId)"
        self.authority = try MSALAuthority(url: URL(string: authorityURL)!)

        print("🔧 Initializing AuthManager with:")
        print("   Client ID: \(clientId)")
        print("   Tenant ID: \(tenantId)")

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

        msalApplication = try MSALPublicClientApplication(configuration: config)
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

        // Check if token expires within next 5 minutes
        return timeRemaining > 300
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
        return try await refreshAccessToken()
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

                _ = self.storageManager.saveAccessToken(accessToken)
                self.storageManager.saveTokenExpiry(expiry)

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

        guard let account = accounts.first else {
            print("   ❌ No account found!")
            throw NSError(domain: "AuthManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "No account found"])
        }

        print("   ✅ Using account: \(account.username ?? "unknown")")
        let parameters = MSALSilentTokenParameters(scopes: GraphConstants.scopes, account: account)
        print("   🔄 Calling acquireTokenSilent...")

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireTokenSilent(with: parameters) { (result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "No result from silent refresh"]))
                    return
                }

                // Update stored tokens
                let accessToken = result.accessToken
                let expiry = result.expiresOn ?? Date().addingTimeInterval(3600) // Default to 1 hour from now

                _ = self.storageManager.saveAccessToken(accessToken)
                self.storageManager.saveTokenExpiry(expiry)

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
