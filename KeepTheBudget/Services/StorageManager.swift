//
//  StorageManager.swift
//  KeepTheBudget
//
//  Manages persistent storage using Keychain and UserDefaults
//

import Foundation

class StorageManager {
    private let keychain = KeychainHelper.shared
    private let userDefaults = UserDefaults.standard

    // MARK: - Token Management

    func saveAccessToken(_ token: String) -> Bool {
        return keychain.save(token, forKey: KeychainKeys.accessToken)
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

    func saveTokenExpiry(_ date: Date) {
        userDefaults.set(date, forKey: KeychainKeys.tokenExpiry)
    }

    func loadTokenExpiry() -> Date? {
        return userDefaults.object(forKey: KeychainKeys.tokenExpiry) as? Date
    }

    func deleteAllTokens() {
        _ = keychain.delete(forKey: KeychainKeys.accessToken)
        _ = keychain.delete(forKey: KeychainKeys.refreshToken)
        userDefaults.removeObject(forKey: KeychainKeys.tokenExpiry)
    }

    // MARK: - MSAL Configuration Management

    func saveClientId(_ clientId: String) -> Bool {
        return keychain.save(clientId, forKey: KeychainKeys.clientId)
    }

    func loadClientId() -> String? {
        return keychain.loadString(forKey: KeychainKeys.clientId)
    }

    func saveTenantId(_ tenantId: String) -> Bool {
        return keychain.save(tenantId, forKey: KeychainKeys.tenantId)
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
