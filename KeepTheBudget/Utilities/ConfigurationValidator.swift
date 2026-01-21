//
//  ConfigurationValidator.swift
//  KeepTheBudget
//
//  Validates MSAL configuration values (clientId, tenantId)
//

import Foundation

struct ConfigurationValidator {
    /// Validates if a string is a valid Client ID (must be a UUID)
    static func isValidClientId(_ string: String) -> Bool {
        return UUID(uuidString: string) != nil
    }

    /// Validates if a string is a valid Tenant ID (UUID or special values)
    static func isValidTenantId(_ string: String) -> Bool {
        let commonTenants = ["common", "organizations", "consumers"]
        return commonTenants.contains(string.lowercased()) ||
               UUID(uuidString: string) != nil
    }

    /// Extracts Client ID from Info.plist CFBundleURLSchemes
    /// Looks for URL scheme matching pattern: msal{clientId}
    static func extractClientIdFromInfoPlist() -> String? {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }

        for urlType in urlTypes {
            if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                for scheme in schemes where scheme.hasPrefix("msal") {
                    let clientId = String(scheme.dropFirst(4))
                    if isValidClientId(clientId) {
                        return clientId
                    }
                }
            }
        }
        return nil
    }
}
