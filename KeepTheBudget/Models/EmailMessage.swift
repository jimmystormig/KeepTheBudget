//
//  EmailMessage.swift
//  KeepTheBudget
//
//  Email data model for Microsoft Graph API integration
//

import Foundation

/// Represents an individual email message from Microsoft Graph API
struct EmailMessage: Identifiable, Codable {
    let id: String
    let subject: String?  // Optional because some emails have null subjects
    let from: EmailAddress?  // Optional because some emails (drafts, system messages) may not have a sender
    let to: [EmailAddress]
    let receivedDateTime: Date
    let bodyPreview: String?  // Optional - First 150 characters from Graph API
    let conversationId: String  // Used for thread grouping
    let hasAttachments: Bool
    let isRead: Bool
    let isSent: Bool  // Computed based on sender matching user email

    /// Display subject with fallback for null values
    var displaySubject: String {
        subject ?? "(No subject)"
    }

    /// Safe body preview
    var safeBodyPreview: String {
        bodyPreview ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id
        case subject
        case from
        case to = "toRecipients"
        case receivedDateTime
        case bodyPreview
        case conversationId
        case hasAttachments
        case isRead
    }

    /// Initialize from Graph API response
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)  // Handle null subjects
        from = try container.decodeIfPresent(EmailAddress.self, forKey: .from)  // Handle missing sender (drafts, system messages)
        to = try container.decode([EmailAddress].self, forKey: .to)
        bodyPreview = try container.decodeIfPresent(String.self, forKey: .bodyPreview)  // Handle null previews
        conversationId = try container.decode(String.self, forKey: .conversationId)
        hasAttachments = try container.decode(Bool.self, forKey: .hasAttachments)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false

        // Parse ISO 8601 date
        let dateString = try container.decode(String.self, forKey: .receivedDateTime)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            receivedDateTime = date
        } else {
            // Fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            receivedDateTime = formatter.date(from: dateString) ?? Date()
        }

        // isSent will be set after decoding by comparing sender to user email
        isSent = false
    }

    /// Manual initializer for testing and user email comparison
    init(id: String, subject: String?, from: EmailAddress?, to: [EmailAddress],
         receivedDateTime: Date, bodyPreview: String?, conversationId: String,
         hasAttachments: Bool, isRead: Bool, isSent: Bool) {
        self.id = id
        self.subject = subject
        self.from = from
        self.to = to
        self.receivedDateTime = receivedDateTime
        self.bodyPreview = bodyPreview
        self.conversationId = conversationId
        self.hasAttachments = hasAttachments
        self.isRead = isRead
        self.isSent = isSent
    }

    /// Create a copy with updated isSent flag
    func withSentStatus(userEmail: String) -> EmailMessage {
        EmailMessage(
            id: id,
            subject: subject,
            from: from,
            to: to,
            receivedDateTime: receivedDateTime,
            bodyPreview: bodyPreview,
            conversationId: conversationId,
            hasAttachments: hasAttachments,
            isRead: isRead,
            isSent: from?.address.caseInsensitiveCompare(userEmail) == .orderedSame
        )
    }
}

/// Email address with optional display name
struct EmailAddress: Codable {
    let name: String?
    let address: String

    enum CodingKeys: String, CodingKey {
        case emailAddress
    }

    enum EmailAddressKeys: String, CodingKey {
        case name
        case address
    }

    /// Graph API returns nested structure: { "emailAddress": { "name": "...", "address": "..." } }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let emailContainer = try container.nestedContainer(keyedBy: EmailAddressKeys.self, forKey: .emailAddress)

        name = try? emailContainer.decode(String.self, forKey: .name)
        address = try emailContainer.decode(String.self, forKey: .address)
    }

    /// Manual initializer
    init(name: String?, address: String) {
        self.name = name
        self.address = address
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var emailContainer = container.nestedContainer(keyedBy: EmailAddressKeys.self, forKey: .emailAddress)

        try emailContainer.encodeIfPresent(name, forKey: .name)
        try emailContainer.encode(address, forKey: .address)
    }

    /// Display string for UI
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return address
    }
}

/// Graph API response wrapper for email list
struct EmailListResponse: Codable {
    let value: [EmailMessage]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}
