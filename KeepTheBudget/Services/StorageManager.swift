//
//  StorageManager.swift
//  KeepTheBudget
//
//  Manages persistent storage using Keychain and UserDefaults
//

import Foundation

/// Snapshot of all keychain configuration loaded in a single operation
/// Used to minimize keychain access prompts during app startup
struct ConfigurationSnapshot {
    let clientId: String?
    let tenantId: String?
    let accessToken: String?
    let refreshToken: String?
    let tokenExpiry: String?

    var hasConfiguration: Bool {
        return clientId != nil && tenantId != nil
    }

    var hasExistingToken: Bool {
        return accessToken != nil
    }

}

final class StorageManager: @unchecked Sendable {
    private let keychain = KeychainHelper.shared
    private let userDefaults = UserDefaults.standard
    private let deprecatedCredentialKeys = [
        "azure_openai_endpoint",
        "azure_openai_api_key",
        "azure_openai_deployment"
    ]

    // MARK: - Token Management

    func saveAccessToken(_ token: String) -> Bool {
        let success = keychain.save(token, forKey: KeychainKeys.accessToken)

        // Also update the bundle to keep it in sync
        if success {
            updateConfigurationBundle()
        }

        return success
    }

    func loadAccessToken() -> String? {
        return keychain.loadString(forKey: KeychainKeys.accessToken)
    }

    func saveRefreshToken(_ token: String) -> Bool {
        return keychain.save(token, forKey: KeychainKeys.refreshToken)
    }

    func loadRefreshToken() -> String? {
        return keychain.loadString(forKey: KeychainKeys.refreshToken)
    }

    func saveTokenExpiry(_ date: Date) -> Bool {
        let timestamp = date.timeIntervalSince1970
        let timestampString = String(timestamp)
        let success = keychain.save(timestampString, forKey: KeychainKeys.tokenExpiry)

        if success {
            updateConfigurationBundle()
        }

        return success
    }

    func loadTokenExpiry() -> Date? {
        // First check keychain
        if let timestampString = keychain.loadString(forKey: KeychainKeys.tokenExpiry),
           let timestamp = TimeInterval(timestampString) {
            return Date(timeIntervalSince1970: timestamp)
        }

        // Migration: Try loading from old UserDefaults location
        if let legacyDate = userDefaults.object(forKey: KeychainKeys.tokenExpiry) as? Date {
            print("⚠️  Migrating token expiry from UserDefaults to Keychain")
            _ = saveTokenExpiry(legacyDate)
            userDefaults.removeObject(forKey: KeychainKeys.tokenExpiry)
            return legacyDate
        }

        return nil
    }

    func deleteAllTokens() {
        _ = keychain.delete(forKey: KeychainKeys.accessToken)
        _ = keychain.delete(forKey: KeychainKeys.refreshToken)
        _ = keychain.delete(forKey: KeychainKeys.tokenExpiry)

        // Also clean up legacy UserDefaults location if it exists
        userDefaults.removeObject(forKey: KeychainKeys.tokenExpiry)

        // Also update the bundle to reflect deleted token
        updateConfigurationBundle()
    }

    // MARK: - MSAL Configuration Management

    func saveClientId(_ clientId: String) -> Bool {
        let success = keychain.save(clientId, forKey: KeychainKeys.clientId)

        // Also update the bundle to keep it in sync
        if success {
            updateConfigurationBundle()
        }

        return success
    }

    func loadClientId() -> String? {
        return keychain.loadString(forKey: KeychainKeys.clientId)
    }

    func saveTenantId(_ tenantId: String) -> Bool {
        let success = keychain.save(tenantId, forKey: KeychainKeys.tenantId)

        // Also update the bundle to keep it in sync
        if success {
            updateConfigurationBundle()
        }

        return success
    }

    func loadTenantId() -> String? {
        return keychain.loadString(forKey: KeychainKeys.tenantId)
    }

    func hasConfiguration() -> Bool {
        return loadClientId() != nil && loadTenantId() != nil
    }

    func deleteConfiguration() {
        _ = keychain.delete(forKey: KeychainKeys.clientId)
        _ = keychain.delete(forKey: KeychainKeys.tenantId)

        // Also delete the bundle
        _ = keychain.deleteConfigurationBundle()
    }

    // MARK: - Bundle Synchronization

    /// Update the configuration bundle to stay in sync with individual items
    /// This is called whenever individual items are saved
    private func updateConfigurationBundle() {
        let expiryTimestamp = loadTokenExpiry().map { String($0.timeIntervalSince1970) }

        let bundle = KeychainConfigurationBundle(
            clientId: loadClientId(),
            tenantId: loadTenantId(),
            accessToken: loadAccessToken(),
            refreshToken: loadRefreshToken(),
            tokenExpiry: expiryTimestamp
        )
        _ = keychain.saveConfigurationBundle(bundle)
    }

    // MARK: - Batch Configuration Loading

    /// Load all keychain configuration in a single operation
    /// Uses a single keychain item (bundle) to minimize prompts to ONE
    func loadConfigurationSnapshot() -> ConfigurationSnapshot {
        print("🔑 Loading configuration snapshot (single keychain item)...")

        // Try to load from bundle first (new approach - single keychain item)
        if let bundle = keychain.loadConfigurationBundle() {
            print("   ✅ Loaded from configuration bundle (single keychain prompt)")
            print("   Client ID: \(bundle.clientId != nil ? "present" : "missing")")
            print("   Tenant ID: \(bundle.tenantId != nil ? "present" : "missing")")
            print("   Access Token: \(bundle.accessToken != nil ? "present" : "missing")")
            print("   Refresh Token: \(bundle.refreshToken != nil ? "present" : "missing")")
            print("   Token Expiry: \(bundle.tokenExpiry != nil ? "present" : "missing")")
            removeDeprecatedCredentialsAndRewriteBundle(bundle)

            return ConfigurationSnapshot(
                clientId: bundle.clientId,
                tenantId: bundle.tenantId,
                accessToken: bundle.accessToken,
                refreshToken: bundle.refreshToken,
                tokenExpiry: bundle.tokenExpiry
            )
        }

        // Fallback: load from separate items (old approach - multiple prompts)
        // This happens on first launch or if bundle doesn't exist yet
        print("   ⚠️  No bundle found, loading from separate items (will trigger migration)")
        let clientId = loadClientId()
        let tenantId = loadTenantId()
        let accessToken = loadAccessToken()
        let refreshToken = loadRefreshToken()
        let tokenExpiry = loadTokenExpiry().map { String($0.timeIntervalSince1970) }

        // Migrate to bundle immediately to avoid future prompts
        let bundle = KeychainConfigurationBundle(
            clientId: clientId,
            tenantId: tenantId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiry: tokenExpiry
        )
        removeDeprecatedCredentialsAndRewriteBundle(bundle)
        print("   ✅ Migrated to configuration bundle for future launches")

        print("   Client ID: \(clientId != nil ? "present" : "missing")")
        print("   Tenant ID: \(tenantId != nil ? "present" : "missing")")
        print("   Access Token: \(accessToken != nil ? "present" : "missing")")
        print("   Refresh Token: \(refreshToken != nil ? "present" : "missing")")
        print("   Token Expiry: \(tokenExpiry != nil ? "present" : "missing")")

        return ConfigurationSnapshot(
            clientId: clientId,
            tenantId: tenantId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiry: tokenExpiry
        )
    }

    private func removeDeprecatedCredentialsAndRewriteBundle(_ bundle: KeychainConfigurationBundle) {
        let bundleSaved = keychain.saveConfigurationBundle(bundle)
        let credentialsDeleted = deprecatedCredentialKeys
            .map { keychain.delete(forKey: $0) }
            .allSatisfy { $0 }

        if !bundleSaved || !credentialsDeleted {
            print("⚠️  Deprecated credentials cleanup was incomplete and will be retried at the next launch")
        }
    }

    // MARK: - Preferences Management

    func savePreferences(_ preferences: AppPreferences) {
        if let encoded = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encoded, forKey: UserDefaultsKeys.preferences)
        }
    }

    func loadPreferences() -> AppPreferences {
        guard let data = userDefaults.data(forKey: UserDefaultsKeys.preferences),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return AppPreferences() // Return default preferences
        }
        return preferences
    }

    // MARK: - Delta Link Management

    func saveDeltaLink(_ link: String) {
        userDefaults.set(link, forKey: UserDefaultsKeys.deltaLink)
    }

    func loadDeltaLink() -> String? {
        return userDefaults.string(forKey: UserDefaultsKeys.deltaLink)
    }

    func clearDeltaLink() {
        userDefaults.removeObject(forKey: UserDefaultsKeys.deltaLink)
    }
}
