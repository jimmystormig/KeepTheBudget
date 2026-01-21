//
//  MigrationManager.swift
//  KeepTheBudget
//
//  Handles auto-migration of configuration from hardcoded values to Keychain storage
//

import Foundation

struct MigrationManager {
    /// Auto-migrates configuration from hardcoded values to Keychain
    /// Only migrates if:
    /// 1. Configuration is not already in Keychain
    /// 2. User has existing tokens (indicates existing installation)
    static func migrateConfigurationIfNeeded(storageManager: StorageManager) {
        // Already migrated
        guard !storageManager.hasConfiguration() else {
            print("ℹ️  Configuration already exists in Keychain")
            return
        }

        // Only migrate if existing installation (has tokens)
        guard storageManager.loadAccessToken() != nil else {
            print("ℹ️  New installation - no migration needed")
            return
        }

        // Auto-migrate from hardcoded legacy values
        // These values are hardcoded here only for migration purposes
        let legacyClientId = "cc73ecf9-b305-4336-b4ac-60753f907258"
        let legacyTenantId = "02b6749b-5ce0-4853-bd5c-a05f9bd9dd3a"

        print("🔄 Migrating configuration from legacy hardcoded values...")
        print("   Client ID: \(legacyClientId)")
        print("   Tenant ID: \(legacyTenantId)")

        let clientIdSaved = storageManager.saveClientId(legacyClientId)
        let tenantIdSaved = storageManager.saveTenantId(legacyTenantId)

        if clientIdSaved && tenantIdSaved {
            print("✅ Auto-migrated configuration from hardcoded values")
        } else {
            print("❌ Failed to migrate configuration")
        }
    }
}
