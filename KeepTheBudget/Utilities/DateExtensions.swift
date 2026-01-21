//
//  DateExtensions.swift
//  KeepTheBudget
//
//  Date utility extensions for time calculations
//

import Foundation

extension Date {
    /// Returns the start of the current day (midnight) in local timezone
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns the end of the current day (23:59:59) in local timezone
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Converts date to ISO 8601 string for Graph API (in UTC)
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime] // Just use standard format with Z
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC
        return formatter.string(from: self)
    }
}

extension Calendar {
    /// Returns the start of the current week (Monday at midnight)
    func startOfWeek(for date: Date) -> Date {
        let weekday = component(.weekday, from: date)

        // weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        // Calculate days from Monday
        let daysFromMonday = (weekday + 5) % 7

        let monday = self.date(byAdding: .day, value: -daysFromMonday, to: date) ?? date
        return startOfDay(for: monday)
    }

    /// Returns the end of the current week (Sunday at 23:59:59)
    func endOfWeek(for date: Date) -> Date {
        let startOfWeek = self.startOfWeek(for: date)
        let sunday = self.date(byAdding: .day, value: 6, to: startOfWeek) ?? date

        var components = DateComponents()
        components.hour = 23
        components.minute = 59
        components.second = 59

        return self.date(bySettingHour: 23, minute: 59, second: 59, of: sunday) ?? sunday
    }
}
