//
//  ChatConversation.swift
//  KeepTheBudget
//
//  Teams chat conversation model for comprehensive report
//

import Foundation

/// Represents a Teams chat conversation with messages
struct ChatConversation: Identifiable {
    let id: String  // chat ID from Graph API
    let topic: String?  // Chat name (may be null for 1:1)
    let chatType: ChatType
    let messages: [ChatMessage]
    let participants: [ChatParticipant]
    let lastMessageDate: Date

    /// Display name for UI (topic or participant names)
    var displayName: String {
        if let topic = topic, !topic.isEmpty {
            return topic
        }
        // For 1:1 or group chats without topic, show participant names
        return participants.map(\.safeDisplayName).joined(separator: ", ")
    }

    /// Total message count
    var totalMessages: Int {
        messages.count
    }

    /// Most recent message preview
    var latestPreview: String {
        messages.last?.displayBody ?? ""
    }

    /// Format for text export
    func toText() -> String {
        var text = """
        \(displayName) [\(chatType.rawValue)] (\(totalMessages) messages)
        """

        for message in messages {
            let timestamp = formatTimestamp(message.createdDateTime)
            let sender = message.from?.safeDisplayName ?? "(System message)"
            text += """

              \(timestamp) | \(sender)
                \(message.displayBody)
            """
        }

        return text
    }

    /// Format timestamp for display
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEE HH:mm"
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
        }

        return formatter.string(from: date)
    }
}

/// Type of Teams chat
enum ChatType: String, Codable {
    case oneOnOne = "oneOnOne"
    case group = "group"
    case meeting = "meeting"
}

/// Individual message in a Teams chat
struct ChatMessage: Identifiable, Codable {
    let id: String
    let from: ChatParticipant?  // Optional because system messages may not have a sender
    let body: String
    let createdDateTime: Date
    let messageType: String

    /// Clean body text with HTML stripped
    var displayBody: String {
        stripHTML(from: body)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case from
        case body
        case createdDateTime
        case messageType
    }

    /// Initialize from Graph API response
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        from = try container.decodeIfPresent(ChatParticipant.self, forKey: .from)
        messageType = try container.decode(String.self, forKey: .messageType)
        createdDateTime = try container.decode(Date.self, forKey: .createdDateTime)

        // Parse message body (Graph API returns nested structure)
        if let bodyContainer = try? container.nestedContainer(keyedBy: BodyKeys.self, forKey: .body) {
            let rawContent = (try? bodyContainer.decode(String.self, forKey: .content)) ?? ""
            body = rawContent
        } else {
            body = ""
        }
    }

    enum BodyKeys: String, CodingKey {
        case content
        case contentType
    }

    /// Strip HTML tags from message content
    private func stripHTML(from html: String) -> String {
        var result = html

        // Replace <p> tags with newlines
        result = result.replacingOccurrences(of: "<p>", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)

        // Replace <br> tags with newlines
        result = result.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)

        // Remove all other HTML tags using regex
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // Decode HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")

        // Trim whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result.isEmpty ? "(Empty message)" : result
    }

    /// Manual initializer for testing
    init(id: String, from: ChatParticipant?, body: String, createdDateTime: Date, messageType: String) {
        self.id = id
        self.from = from
        self.body = body
        self.createdDateTime = createdDateTime
        self.messageType = messageType
    }
}

/// Participant in a Teams chat
struct ChatParticipant: Identifiable, Codable {
    let id: String
    let displayName: String?  // Optional because some participants (bots, guests) may have null displayName
    let email: String?

    /// Safe display name with fallback
    var safeDisplayName: String {
        if let name = displayName, !name.isEmpty {
            return name
        }
        if let email = email, !email.isEmpty {
            return email
        }
        return "Unknown User"
    }

    enum CodingKeys: String, CodingKey {
        case user
        case userId
        case displayName
        case email
    }

    enum UserKeys: String, CodingKey {
        case id
        case displayName
        case userPrincipalName
    }

    /// Initialize from Graph API response
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Graph API for chat messages has nested structure: from.user.displayName
        if let userContainer = try? container.nestedContainer(keyedBy: UserKeys.self, forKey: .user) {
            // Parse from nested user object (chat messages)
            id = (try? userContainer.decode(String.self, forKey: .id)) ?? UUID().uuidString
            displayName = try? userContainer.decode(String.self, forKey: .displayName)
            email = try? userContainer.decode(String.self, forKey: .userPrincipalName)
        } else {
            // Fallback for direct structure (chat members)
            id = (try? container.decode(String.self, forKey: .userId)) ?? UUID().uuidString
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            email = try? container.decode(String.self, forKey: .email)
        }
    }

    /// Encode to JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .userId)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(email, forKey: .email)
    }

    /// Manual initializer for testing
    init(id: String, displayName: String?, email: String?) {
        self.id = id
        self.displayName = displayName
        self.email = email
    }
}

/// Graph API response for chat list
struct ChatListResponse: Codable {
    let value: [Chat]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

/// Individual chat from Graph API
struct Chat: Codable {
    let id: String
    let topic: String?
    let chatType: String
    let members: [ChatParticipant]?

    enum CodingKeys: String, CodingKey {
        case id
        case topic
        case chatType
        case members
    }
}

/// Graph API response for chat messages
struct ChatMessageListResponse: Codable {
    let value: [ChatMessage]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}
