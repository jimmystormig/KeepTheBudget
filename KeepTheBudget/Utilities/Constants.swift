//
//  Constants.swift
//  KeepTheBudget
//
//  Application constants and Microsoft Graph API endpoints
//

import Foundation

enum GraphConstants {
    static let baseURL = "https://graph.microsoft.com/v1.0"

    // Endpoints
    static let meEndpoint = "\(baseURL)/me"
    static let calendarsEndpoint = "\(baseURL)/me/calendars"
    static let messagesEndpoint = "\(baseURL)/me/messages"
    static let chatsEndpoint = "\(baseURL)/me/chats"

    static func mailFolderMessagesEndpoint(folderId: String) -> String {
        let encodedFolderId = folderId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? folderId
        return "\(baseURL)/me/mailFolders/\(encodedFolderId)/messages"
    }

    static func eventsEndpoint(calendarId: String) -> String {
        // URL encode the calendar ID as it may contain special characters
        let encodedCalendarId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        return "\(baseURL)/me/calendars/\(encodedCalendarId)/events"
    }

    static func chatMessagesEndpoint(chatId: String) -> String {
        let encodedChatId = chatId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? chatId
        return "\(baseURL)/me/chats/\(encodedChatId)/messages"
    }

    // Scopes
    // Note: Don't include offline_access - it's a reserved scope that MSAL adds automatically
    static let scopes = [
        "Calendars.Read",
        "User.Read",
        "Mail.Read",  // Phase 1: Email integration
        "Chat.Read"   // Phase 2: Teams chat integration
    ]
}

enum OAuthConstants {
    /// Returns the OAuth authority URL for the given tenant
    static func authorityURL(tenantId: String) -> String {
        return "https://login.microsoftonline.com/\(tenantId)"
    }

    /// Device code initiation endpoint
    static func deviceCodeEndpoint(tenantId: String) -> String {
        return "\(authorityURL(tenantId: tenantId))/oauth2/v2.0/devicecode"
    }

    /// Token endpoint (for both device code polling and refresh token)
    static func tokenEndpoint(tenantId: String) -> String {
        return "\(authorityURL(tenantId: tenantId))/oauth2/v2.0/token"
    }

    /// Scopes for OAuth flow (includes offline_access for refresh tokens)
    static let scopes = [
        "Calendars.Read",
        "User.Read",
        "Mail.Read",
        "Chat.Read",
        "offline_access"  // Required to get refresh tokens
    ]

    /// Scope string formatted for OAuth requests
    static var scopeString: String {
        return scopes.joined(separator: " ")
    }
}

enum KeychainKeys {
    static let accessToken = "office365_access_token"
    static let refreshToken = "office365_refresh_token"
    static let tokenExpiry = "office365_token_expiry"
    static let clientId = "msal_client_id"
    static let tenantId = "msal_tenant_id"
}

enum AzureOpenAIKeys {
    static let endpoint = "azure_openai_endpoint"
    static let apiKey = "azure_openai_api_key"
    static let deploymentName = "azure_openai_deployment"
}

enum UserDefaultsKeys {
    static let preferences = "app_preferences"
    static let deltaLink = "calendar_delta_link"
}
