//
//  EmailThread.swift
//  KeepTheBudget
//
//  Email thread grouping model for conversation view
//

import Foundation

/// Represents a grouped email conversation thread
struct EmailThread: Identifiable {
    let id: String  // conversationId from Graph API
    let subject: String  // Cleaned subject (RE:/FW: removed)
    let messages: [EmailMessage]
    let startDate: Date  // First message in thread
    let lastDate: Date  // Most recent message
    let participantCount: Int  // Unique participants

    /// Initialize from grouped messages
    init(id: String, messages: [EmailMessage]) {
        self.id = id
        self.messages = messages.sorted { $0.receivedDateTime < $1.receivedDateTime }

        // Extract and clean subject
        if let firstMessage = self.messages.first, let subject = firstMessage.subject {
            self.subject = Self.cleanSubject(subject)
        } else {
            self.subject = "(No subject)"
        }

        // Calculate date range
        self.startDate = self.messages.first?.receivedDateTime ?? Date()
        self.lastDate = self.messages.last?.receivedDateTime ?? Date()

        // Count unique participants
        var participants = Set<String>()
        for message in messages {
            if let from = message.from {
                participants.insert(from.address.lowercased())
            }
            for recipient in message.to {
                participants.insert(recipient.address.lowercased())
            }
        }
        self.participantCount = participants.count
    }

    /// Display subject (for UI)
    var displaySubject: String {
        subject.isEmpty ? "(No subject)" : subject
    }

    /// Total message count
    var totalMessages: Int {
        messages.count
    }

    /// Sent vs received breakdown
    var sentCount: Int {
        messages.filter { $0.isSent }.count
    }

    var receivedCount: Int {
        messages.filter { !$0.isSent }.count
    }

    var unreadReceivedCount: Int {
        messages.filter { !$0.isSent && !$0.isRead }.count
    }

    /// Most recent message preview
    var latestPreview: String {
        messages.last?.safeBodyPreview ?? ""
    }

    /// Format for text export
    func toText() -> String {
        var text = """
        \(displaySubject) (\(totalMessages) messages, \(participantCount) participants)
        """

        for message in messages {
            let direction = message.isSent ? "→" : "←"
            let timestamp = formatTimestamp(message.receivedDateTime)
            let sender = message.from?.displayName ?? "(Unknown sender)"
            text += """

              \(direction) \(timestamp) | \(sender)
                \(message.safeBodyPreview)
            """
        }

        return text
    }

    /// Remove RE:, FW:, FWD: prefixes from subject
    private static func cleanSubject(_ subject: String) -> String {
        var cleaned = subject.trimmingCharacters(in: .whitespaces)

        let prefixes = ["RE:", "FW:", "FWD:", "Re:", "Fw:", "Fwd:"]
        var didRemove = true

        while didRemove {
            didRemove = false
            for prefix in prefixes {
                if cleaned.hasPrefix(prefix) {
                    cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    didRemove = true
                    break
                }
            }
        }

        return cleaned
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
