//
//  KeychainHelper.swift
//  KeepTheBudget
//
//  Secure storage for tokens using macOS Keychain
//

import Foundation
import Security
import LocalAuthentication

/// Bundle all configuration values into a single keychain item
/// This ensures only ONE keychain prompt instead of three separate ones
struct KeychainConfigurationBundle: Codable {
    let clientId: String?
    let tenantId: String?
    let accessToken: String?
}

class KeychainHelper {
    static let shared = KeychainHelper()

    private let service: String
    private let configBundleKey = "configuration_bundle"

    private init() {
        self.service = Bundle.main.bundleIdentifier ?? "com.nexer.KeepTheBudget"
    }

    func save(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func save(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }

    func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func loadString(forKey key: String) -> String? {
        guard let data = load(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Configuration Bundle (Single Keychain Item)

    /// Save configuration bundle as a single keychain item
    /// This results in only ONE keychain prompt instead of three
    func saveConfigurationBundle(_ bundle: KeychainConfigurationBundle) -> Bool {
        guard let data = try? JSONEncoder().encode(bundle) else {
            print("❌ Failed to encode configuration bundle")
            return false
        }

        return save(data, forKey: configBundleKey)
    }

    /// Load configuration bundle from single keychain item
    /// This results in only ONE keychain prompt
    func loadConfigurationBundle() -> KeychainConfigurationBundle? {
        guard let data = load(forKey: configBundleKey) else {
            print("   No configuration bundle found in keychain")
            return nil
        }

        guard let bundle = try? JSONDecoder().decode(KeychainConfigurationBundle.self, from: data) else {
            print("❌ Failed to decode configuration bundle")
            return nil
        }

        return bundle
    }

    /// Delete configuration bundle
    func deleteConfigurationBundle() -> Bool {
        return delete(forKey: configBundleKey)
    }
}
