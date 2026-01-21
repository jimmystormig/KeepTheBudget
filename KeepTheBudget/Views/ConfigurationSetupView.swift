//
//  ConfigurationSetupView.swift
//  KeepTheBudget
//
//  First-launch configuration screen for setting up Client ID and Tenant ID
//

import SwiftUI

struct ConfigurationSetupView: View {
    let storageManager: StorageManager
    let onComplete: () -> Void

    @State private var clientId: String = ""
    @State private var tenantId: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Configuration Required")
                .font(.title)
                .fontWeight(.bold)

            Text("Enter your Microsoft Entra app registration details to continue.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 15) {
                // Client ID field
                VStack(alignment: .leading, spacing: 5) {
                    Text("Client ID")
                        .font(.headline)
                    TextField("00000000-0000-0000-0000-000000000000", text: $clientId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                    Text("Application (client) ID from Azure Portal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Tenant ID field
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tenant ID")
                        .font(.headline)
                    TextField("00000000-0000-0000-0000-000000000000", text: $tenantId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                    Text("Directory (tenant) ID from Azure Portal, or 'common' for multi-tenant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if isSaving {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Saving configuration...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)
            } else {
                Button("Save Configuration") {
                    saveConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(clientId.isEmpty || tenantId.isEmpty)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(30)
        .frame(width: 500, height: 500)
    }

    private func saveConfiguration() {
        // Clear previous error
        errorMessage = nil

        // Trim whitespace
        let trimmedClientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTenantId = tenantId.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate inputs
        guard ConfigurationValidator.isValidClientId(trimmedClientId) else {
            errorMessage = "Invalid Client ID. Must be a valid UUID format."
            return
        }

        guard ConfigurationValidator.isValidTenantId(trimmedTenantId) else {
            errorMessage = "Invalid Tenant ID. Must be a UUID or 'common', 'organizations', or 'consumers'."
            return
        }

        // Check if Info.plist matches
        if let plistClientId = ConfigurationValidator.extractClientIdFromInfoPlist(),
           plistClientId != trimmedClientId {
            errorMessage = "Warning: Client ID doesn't match Info.plist redirect URI. Authentication may fail."
            print("⚠️  Client ID mismatch:")
            print("   Entered: \(trimmedClientId)")
            print("   Info.plist: \(plistClientId)")
        }

        isSaving = true

        // Save to Keychain
        let clientIdSaved = storageManager.saveClientId(trimmedClientId)
        let tenantIdSaved = storageManager.saveTenantId(trimmedTenantId)

        isSaving = false

        if clientIdSaved && tenantIdSaved {
            print("✅ Configuration saved successfully")
            print("   Client ID: \(trimmedClientId)")
            print("   Tenant ID: \(trimmedTenantId)")
            onComplete()
        } else {
            errorMessage = "Failed to save configuration to Keychain. Please try again."
            print("❌ Failed to save configuration")
        }
    }
}
