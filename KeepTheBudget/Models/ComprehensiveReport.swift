//
//  ComprehensiveReport.swift
//  KeepTheBudget
//
//  Combined report model for calendar events, emails, and Teams chats
//

import Foundation

/// Comprehensive work activity report combining calendar, email, and chat data
struct ComprehensiveReport {
    let timeReport: TimeReport  // Existing calendar-based time report
    let emailThreads: [EmailThread]
    let chatConversations: [ChatConversation]?  // Optional: Phase 2
    let startDate: Date
    let endDate: Date

    /// Initialize with all data sources
    init(timeReport: TimeReport, emailThreads: [EmailThread],
         chatConversations: [ChatConversation]? = nil,
         startDate: Date, endDate: Date) {
        self.timeReport = timeReport
        self.emailThreads = emailThreads
        self.chatConversations = chatConversations
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Combined text export for clipboard and AI analysis
    func toText() -> String {
        var text = """
        COMPREHENSIVE WORK REPORT
        Period: \(formatDate(startDate)) to \(formatDate(endDate))


        """

        // Calendar Events Section
        text += """
        ═══════════════════════════════════════════
        📅 CALENDAR EVENTS
        ═══════════════════════════════════════════

        \(timeReport.toText())


        """

        // Email Threads Section
        text += """
        ═══════════════════════════════════════════
        📧 EMAIL COMMUNICATIONS (\(emailThreads.count) threads)
        ═══════════════════════════════════════════

        """

        if emailThreads.isEmpty {
            text += "No emails in this period.\n"
        } else {
            for (index, thread) in emailThreads.enumerated() {
                text += "\n\(index + 1). \(thread.toText())\n"
            }
        }

        // Teams Chat Section (Phase 2)
        if let chats = chatConversations {
            text += """


            ═══════════════════════════════════════════
            💬 TEAMS CHATS (\(chats.count) conversations)
            ═══════════════════════════════════════════

            """

            if chats.isEmpty {
                text += "No chats in this period.\n"
            } else {
                for (index, chat) in chats.enumerated() {
                    text += "\n\(index + 1). \(chat.toText())\n"
                }
            }
        }

        text += """


        ═══════════════════════════════════════════
        End of Report
        ═══════════════════════════════════════════
        """

        return text
    }

    /// Total communication items
    var totalCommunications: Int {
        emailThreads.count + (chatConversations?.count ?? 0)
    }

    /// Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Placeholder for Phase 2

/// Teams chat conversation model (Phase 2 implementation)
struct ChatConversation: Identifiable {
    let id: String
    let topic: String?
    let chatType: String
    let messages: [ChatMessage]
    let participants: [ChatParticipant]
    let lastMessageDate: Date

    var displayName: String {
        topic ?? participants.map(\.displayName).joined(separator: ", ")
    }

    func toText() -> String {
        var text = "\(displayName) (\(messages.count) messages)"
        // Detailed formatting will be implemented in Phase 2
        return text
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let from: ChatParticipant
    let body: String
    let createdDateTime: Date
}

struct ChatParticipant: Identifiable {
    let id: String
    let displayName: String
    let email: String?
}
