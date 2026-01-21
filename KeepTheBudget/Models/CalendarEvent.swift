//
//  CalendarEvent.swift
//  KeepTheBudget
//
//  Represents a calendar event from Office 365
//

import Foundation

struct CalendarEvent {
    let id: String
    let subject: String
    let start: Date
    let end: Date
    let organizerEmail: String
    let isAllDay: Bool

    /// Duration in minutes. All-day events count as 480 minutes (8 hours)
    var durationMinutes: Int {
        if isAllDay {
            return 480 // 8 hours
        } else {
            return Int(end.timeIntervalSince(start) / 60)
        }
    }

    /// Extracts category from subject (text before first " - ")
    /// Returns nil if subject doesn't contain " - "
    var category: String? {
        guard let dashRange = subject.range(of: " - ") else {
            return nil
        }
        let extracted = String(subject[..<dashRange.lowerBound])
        let trimmed = extracted.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Returns true if event subject contains " - " (required for tracking)
    var isValidForTracking: Bool {
        return subject.contains(" - ")
    }
}

// Graph API response structures
struct GraphEventResponse: Codable {
    let value: [GraphEvent]
}

struct GraphEvent: Codable {
    let id: String
    let subject: String
    let start: GraphDateTime
    let end: GraphDateTime
    let organizer: GraphOrganizer
    let isAllDay: Bool

    func toCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: id,
            subject: subject,
            start: start.toDate(),
            end: end.toDate(),
            organizerEmail: organizer.emailAddress.address,
            isAllDay: isAllDay
        )
    }
}

struct GraphDateTime: Codable {
    let dateTime: String
    let timeZone: String

    func toDate() -> Date {
        // Graph API returns dates like "2026-01-20T09:00:00.0000000" with timezone in separate field
        // We need to parse this correctly

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        formatter.timeZone = TimeZone(identifier: timeZone) ?? TimeZone(secondsFromGMT: 0)

        if let date = formatter.date(from: dateTime) {
            return date
        }

        // Fallback: try without fractional seconds
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: dateTime) {
            return date
        }

        print("⚠️ Failed to parse date: '\(dateTime)' with timezone '\(timeZone)'")
        return Date()
    }
}

struct GraphOrganizer: Codable {
    let emailAddress: GraphEmailAddress
}

struct GraphEmailAddress: Codable {
    let address: String
    let name: String?
}
