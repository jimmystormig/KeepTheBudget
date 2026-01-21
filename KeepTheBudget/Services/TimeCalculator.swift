//
//  TimeCalculator.swift
//  KeepTheBudget
//
//  Calculates time totals from calendar events
//

import Foundation

class TimeCalculator {
    /// Returns the date range for today (midnight to now)
    func getDailyRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        return (startOfDay, now)
    }

    /// Returns the date range for current week (Monday 00:00 to Sunday 23:59)
    func getWeeklyRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        let startOfWeek = calendar.startOfWeek(for: now)
        let endOfWeek = calendar.endOfWeek(for: now)

        return (startOfWeek, endOfWeek)
    }

    /// Calculates total minutes from a list of calendar events
    /// All-day events are counted as 480 minutes (8 hours)
    func calculateTotalMinutes(events: [CalendarEvent]) -> Int {
        var totalMinutes = 0

        for event in events {
            totalMinutes += event.durationMinutes
        }

        return totalMinutes
    }

    /// Calculates total minutes for events within a specific date range
    /// Useful for filtering events that span across boundaries
    func calculateTotalMinutes(events: [CalendarEvent], from startDate: Date, to endDate: Date) -> Int {
        let filteredEvents = events.filter { event in
            // Event must start before range ends and end after range starts
            event.start < endDate && event.end > startDate
        }

        return calculateTotalMinutes(events: filteredEvents)
    }

    /// Calculates time breakdown by category
    /// Only includes events that contain " - " in subject
    /// Returns dictionary of category names to total minutes
    func calculateCategoryBreakdown(events: [CalendarEvent]) -> [String: Int] {
        var categoryMinutes: [String: Int] = [:]

        for event in events {
            // Only process events with valid category
            guard let category = event.category else {
                continue
            }

            categoryMinutes[category, default: 0] += event.durationMinutes
        }

        return categoryMinutes
    }
}
