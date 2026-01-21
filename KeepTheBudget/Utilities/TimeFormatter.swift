//
//  TimeFormatter.swift
//  KeepTheBudget
//
//  Formats time durations for display
//

import Foundation

class TimeFormatter {
    /// Formats minutes into "Xh Ym" format
    /// Examples: "8h 0m", "6h 30m", "0h 45m"
    static func format(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    /// Formats minutes into verbose format
    /// Examples: "8 hours", "6 hours 30 minutes", "45 minutes"
    static func formatVerbose(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours == 0 {
            return "\(mins) minute\(mins == 1 ? "" : "s")"
        } else if mins == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(mins) minute\(mins == 1 ? "" : "s")"
        }
    }

    /// Formats a date as relative time (e.g., "2 min ago", "just now")
    static func formatRelativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)

        if minutes < 1 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes) min ago"
        } else {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
    }
}
