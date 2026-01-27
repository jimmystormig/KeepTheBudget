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
    let azureOpenAIEndpoint: String?
    let azureOpenAIApiKey: String?
    let azureOpenAIDeploymentName: String?

    var hasConfiguration: Bool {
        return clientId != nil && tenantId != nil
    }

    var hasExistingToken: Bool {
        return accessToken != nil
    }

    var hasAzureOpenAIConfiguration: Bool {
        return azureOpenAIEndpoint != nil && azureOpenAIApiKey != nil && azureOpenAIDeploymentName != nil
    }
}

class StorageManager {
    private let keychain = KeychainHelper.shared
    private let userDefaults = UserDefaults.standard

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

    // MARK: - Azure OpenAI Configuration Management

    func saveAzureOpenAIConfig(_ config: AzureOpenAIConfiguration) -> Bool {
        let success = keychain.save(config.endpoint, forKey: AzureOpenAIKeys.endpoint) &&
                     keychain.save(config.apiKey, forKey: AzureOpenAIKeys.apiKey) &&
                     keychain.save(config.deploymentName, forKey: AzureOpenAIKeys.deploymentName)

        // Update the bundle to keep it in sync
        if success {
            updateConfigurationBundle()
        }

        return success
    }

    func loadAzureOpenAIConfig() -> AzureOpenAIConfiguration? {
        guard let endpoint = keychain.loadString(forKey: AzureOpenAIKeys.endpoint),
              let apiKey = keychain.loadString(forKey: AzureOpenAIKeys.apiKey),
              let deploymentName = keychain.loadString(forKey: AzureOpenAIKeys.deploymentName) else {
            return nil
        }

        return AzureOpenAIConfiguration(
            endpoint: endpoint,
            apiKey: apiKey,
            deploymentName: deploymentName
        )
    }

    func deleteAzureOpenAIConfig() {
        _ = keychain.delete(forKey: AzureOpenAIKeys.endpoint)
        _ = keychain.delete(forKey: AzureOpenAIKeys.apiKey)
        _ = keychain.delete(forKey: AzureOpenAIKeys.deploymentName)

        // Update the bundle
        updateConfigurationBundle()
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
            tokenExpiry: expiryTimestamp,
            azureOpenAIEndpoint: keychain.loadString(forKey: AzureOpenAIKeys.endpoint),
            azureOpenAIApiKey: keychain.loadString(forKey: AzureOpenAIKeys.apiKey),
            azureOpenAIDeploymentName: keychain.loadString(forKey: AzureOpenAIKeys.deploymentName)
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
            print("   Azure OpenAI: \(bundle.azureOpenAIEndpoint != nil ? "configured" : "not configured")")

            return ConfigurationSnapshot(
                clientId: bundle.clientId,
                tenantId: bundle.tenantId,
                accessToken: bundle.accessToken,
                refreshToken: bundle.refreshToken,
                tokenExpiry: bundle.tokenExpiry,
                azureOpenAIEndpoint: bundle.azureOpenAIEndpoint,
                azureOpenAIApiKey: bundle.azureOpenAIApiKey,
                azureOpenAIDeploymentName: bundle.azureOpenAIDeploymentName
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
        let azureEndpoint = keychain.loadString(forKey: AzureOpenAIKeys.endpoint)
        let azureApiKey = keychain.loadString(forKey: AzureOpenAIKeys.apiKey)
        let azureDeployment = keychain.loadString(forKey: AzureOpenAIKeys.deploymentName)

        // Migrate to bundle immediately to avoid future prompts
        let bundle = KeychainConfigurationBundle(
            clientId: clientId,
            tenantId: tenantId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiry: tokenExpiry,
            azureOpenAIEndpoint: azureEndpoint,
            azureOpenAIApiKey: azureApiKey,
            azureOpenAIDeploymentName: azureDeployment
        )
        _ = keychain.saveConfigurationBundle(bundle)
        print("   ✅ Migrated to configuration bundle for future launches")

        print("   Client ID: \(clientId != nil ? "present" : "missing")")
        print("   Tenant ID: \(tenantId != nil ? "present" : "missing")")
        print("   Access Token: \(accessToken != nil ? "present" : "missing")")
        print("   Refresh Token: \(refreshToken != nil ? "present" : "missing")")
        print("   Token Expiry: \(tokenExpiry != nil ? "present" : "missing")")
        print("   Azure OpenAI: \(azureEndpoint != nil ? "configured" : "not configured")")

        return ConfigurationSnapshot(
            clientId: clientId,
            tenantId: tenantId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiry: tokenExpiry,
            azureOpenAIEndpoint: azureEndpoint,
            azureOpenAIApiKey: azureApiKey,
            azureOpenAIDeploymentName: azureDeployment
        )
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
