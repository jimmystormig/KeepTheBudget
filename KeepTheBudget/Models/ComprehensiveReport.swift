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
    let remainingDayPlan: RemainingDayPlan?
    let startDate: Date
    let endDate: Date

    /// Initialize with all data sources
    init(timeReport: TimeReport, emailThreads: [EmailThread],
         chatConversations: [ChatConversation]? = nil,
         remainingDayPlan: RemainingDayPlan? = nil,
         startDate: Date, endDate: Date) {
        self.timeReport = timeReport
        self.emailThreads = emailThreads
        self.chatConversations = chatConversations
        self.remainingDayPlan = remainingDayPlan
        self.startDate = startDate
        self.endDate = endDate
    }

    /// Combined text export for clipboard and AI analysis
    func toText() -> String {
        var text = """
        COMPREHENSIVE WORK REPORT
        Period: \(formatDate(startDate)) to \(formatDate(endDate))
        Summary: \(workSummary)


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

        if let remainingDayPlan = remainingDayPlan {
            text += """


            ═══════════════════════════════════════════
            ✅ WHAT TO DO TODAY
            ═══════════════════════════════════════════

            \(remainingDayPlan.toText())
            """
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

    var workSummary: String {
        var parts: [String] = []

        if let primaryGroup = timeReport.firstLevelGroups.max(by: { $0.totalMinutes < $1.totalMinutes }) {
            parts.append("I spent most of yesterday on \(primaryGroup.name) (\(TimeFormatter.format(minutes: primaryGroup.totalMinutes))).")
        } else {
            parts.append("I had no tracked calendar work yesterday.")
        }

        let secondaryGroups = timeReport.firstLevelGroups
            .sorted(by: { $0.totalMinutes > $1.totalMinutes })
            .dropFirst()
            .prefix(2)
            .map(\.name)

        if !secondaryGroups.isEmpty {
            parts.append("I also moved forward \(secondaryGroups.joined(separator: ", ")).")
        }

        if !emailThreads.isEmpty || (chatConversations?.isEmpty == false) {
            let chatCount = chatConversations?.count ?? 0
            parts.append("I handled \(emailThreads.count) email thread\(emailThreads.count == 1 ? "" : "s") and \(chatCount) Teams conversation\(chatCount == 1 ? "" : "s").")
        }

        return parts.joined(separator: " ")
    }

    /// Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct RemainingDayPlan {
    let generatedAt: Date
    let endOfDay: Date
    let upcomingEvents: [CalendarEvent]
    let unreadEmailThreads: [EmailThread]
    let unreadChatConversations: [ChatConversation]

    var summary: String {
        var parts: [String] = []

        if let focus = primaryFocus {
            parts.append("Today I should focus on \(focus).")
        } else {
            parts.append("Today I should work through the remaining inbox and Teams follow-ups.")
        }

        if upcomingEvents.isEmpty {
            parts.append("I have no more calendar events scheduled for the rest of the day.")
        } else {
            parts.append("I have \(upcomingEvents.count) scheduled event\(upcomingEvents.count == 1 ? "" : "s") left today.")
        }

        if let blockers = blockerSummary {
            parts.append("Possible blockers: \(blockers).")
        } else {
            parts.append("I do not see a clear blocker right now.")
        }

        return parts.joined(separator: " ")
    }

    var priorityHighlights: [String] {
        var highlights: [String] = []

        if let nextEvent = upcomingEvents.sorted(by: { $0.start < $1.start }).first {
            highlights.append("Prepare for \(nextEvent.subject) at \(formatTime(nextEvent.start)).")
        }

        if let urgentThread = unreadEmailThreads.first {
            let unreadCount = max(urgentThread.unreadReceivedCount, 1)
            highlights.append("Review inbox thread \"\(urgentThread.displaySubject)\" with \(unreadCount) unread message\(unreadCount == 1 ? "" : "s").")
        }

        if let urgentChat = unreadChatConversations.first {
            highlights.append("Check Teams conversation \"\(urgentChat.displayName)\" for the latest unread updates.")
        }

        return highlights
    }

    func toText() -> String {
        var text = """
        Generated: \(formatDate(generatedAt))
        Remaining day ends: \(formatDate(endOfDay))

        Summary: \(summary)

        📅 UPCOMING CALENDAR (\(upcomingEvents.count) events)
        """

        if !priorityHighlights.isEmpty {
            text += "\n\nPRIORITIES\n"
            for (index, item) in priorityHighlights.enumerated() {
                text += "\(index + 1). \(item)\n"
            }
        }

        if upcomingEvents.isEmpty {
            text += "\nNo remaining calendar events today.\n"
        } else {
            for (index, event) in upcomingEvents.enumerated() {
                text += "\n\(index + 1). \(formatEvent(event))\n"
            }
        }

        text += "\n📧 UNREAD EMAIL (\(unreadEmailThreads.count) threads)\n"
        if unreadEmailThreads.isEmpty {
            text += "No unread email.\n"
        } else {
            for (index, thread) in unreadEmailThreads.enumerated() {
                text += "\n\(index + 1). \(thread.toText())\n"
            }
        }

        text += "\n💬 UNREAD TEAMS MESSAGES (\(unreadChatConversations.count) conversations)\n"
        if unreadChatConversations.isEmpty {
            text += "No unread Teams messages.\n"
        } else {
            for (index, chat) in unreadChatConversations.enumerated() {
                text += "\n\(index + 1). \(chat.toText())\n"
            }
        }

        return text
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var primaryFocus: String? {
        if let nextEvent = upcomingEvents.sorted(by: { $0.start < $1.start }).first {
            return "\(nextEvent.subject) before \(formatTime(nextEvent.start))"
        }

        if let unreadThread = unreadEmailThreads.first {
            return "the inbox thread \"\(unreadThread.displaySubject)\""
        }

        if let unreadChat = unreadChatConversations.first {
            return "the Teams conversation \"\(unreadChat.displayName)\""
        }

        return nil
    }

    private var blockerSummary: String? {
        var blockers: [String] = []

        if unreadEmailThreads.count >= 5 {
            blockers.append("\(unreadEmailThreads.count) unread inbox threads need triage")
        }

        if unreadChatConversations.count >= 5 {
            blockers.append("\(unreadChatConversations.count) unread Teams conversations may hide pending decisions")
        }

        if let nextEvent = upcomingEvents.sorted(by: { $0.start < $1.start }).first {
            let minutesUntil = Int(nextEvent.start.timeIntervalSince(generatedAt) / 60)
            if minutesUntil <= 30 {
                blockers.append("limited focus time before \(nextEvent.subject) at \(formatTime(nextEvent.start))")
            }
        }

        return blockers.isEmpty ? nil : blockers.joined(separator: "; ")
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatEvent(_ event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeRange = event.isAllDay
            ? "All day"
            : "\(formatter.string(from: event.start))-\(formatter.string(from: event.end))"
        return "\(timeRange) | \(event.subject)"
    }
}
