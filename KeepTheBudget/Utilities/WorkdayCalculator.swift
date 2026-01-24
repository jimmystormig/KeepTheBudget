//
//  WorkdayCalculator.swift
//  KeepTheBudget
//
//  Purpose: Calculate workday dates for daily meeting report ranges
//

import Foundation

class WorkdayCalculator {
    /// Returns last workday at specified time (Mon-Fri logic)
    /// - Parameters:
    ///   - hour: Hour of day (0-23)
    ///   - minute: Minute of hour (0-59)
    /// - Returns: Date representing last workday at the specified time
    ///
    /// Logic:
    /// - Mon-Fri: Previous day (or Friday if Monday)
    /// - Sat/Sun: Friday
    static func lastWorkdayAt(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()

        // Get current weekday (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
        let currentWeekday = calendar.component(.weekday, from: now)

        let daysBack: Int
        switch currentWeekday {
        case 1: // Sunday → Friday (2 days back)
            daysBack = 2
        case 2: // Monday → Friday (3 days back)
            daysBack = 3
        case 7: // Saturday → Friday (1 day back)
            daysBack = 1
        default: // Tue-Fri → Previous day (1 day back)
            daysBack = 1
        }

        // Calculate previous workday
        guard let previousDay = calendar.date(byAdding: .day, value: -daysBack, to: now) else {
            return now
        }

        // Set to specified time
        var components = calendar.dateComponents([.year, .month, .day], from: previousDay)
        components.hour = hour
        components.minute = minute
        components.second = 0

        return calendar.date(from: components) ?? now
    }

    /// Check if date is a workday (Mon-Fri)
    /// - Parameter date: Date to check
    /// - Returns: true if Monday-Friday, false if Saturday-Sunday
    static func isWorkday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        return weekday >= 2 && weekday <= 6 // Mon-Fri
    }

    /// Get previous workday before given date
    /// - Parameter date: Reference date
    /// - Returns: Previous Monday-Friday date
    private static func previousWorkday(before date: Date) -> Date {
        let calendar = Calendar.current
        var currentDate = date

        // Keep going back until we find a workday
        repeat {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                return date
            }
            currentDate = previousDay
        } while !isWorkday(currentDate)

        return currentDate
    }
}
