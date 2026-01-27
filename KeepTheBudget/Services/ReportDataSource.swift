//
//  ReportDataSource.swift
//  KeepTheBudget
//
//  Protocol for fetching events from various data sources (Calendar, Jira, Teams, etc.)
//  Enables extensibility for future data sources beyond Office 365 Calendar
//

import Foundation

/// Protocol for report data sources
protocol ReportDataSource {
    /// Fetch events for a specific date range
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    /// - Returns: Array of calendar events (or throws error)
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent]
}

/// Calendar-based data source using Microsoft Graph API
class CalendarDataSource: ReportDataSource {
    let graphAPIService: GraphAPIService
    let storageManager: StorageManager

    init(graphAPIService: GraphAPIService, storageManager: StorageManager) {
        self.graphAPIService = graphAPIService
        self.storageManager = storageManager
    }

    /// Fetch calendar events from Office 365 via Microsoft Graph API
    /// Filters to user's own events with valid tracking format
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        // 1. Get selected calendar ID
        let preferences = storageManager.loadPreferences()
        guard let calendarId = preferences.selectedCalendarId else {
            throw ReportDataSourceError.noCalendarSelected
        }

        // 2. Fetch user profile for email (to filter organizer)
        let userProfile = try await graphAPIService.fetchUserProfile()

        // 3. Fetch events from Graph API
        let events = try await graphAPIService.fetchEvents(
            calendarId: calendarId,
            from: startDate,
            to: endDate
        )

        // 4. Filter to user's own events (only filter needed)
        let ownEvents = events.filter {
            $0.organizerEmail.caseInsensitiveCompare(userProfile.mail) == .orderedSame
        }

        return ownEvents
    }
}

/// Errors specific to report data sources
enum ReportDataSourceError: Error, LocalizedError {
    case noCalendarSelected
    case networkError
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .noCalendarSelected:
            return "No calendar selected. Please select a calendar in Settings."
        case .networkError:
            return "Network error occurred while fetching events."
        case .authenticationFailed:
            return "Authentication failed. Please sign in again."
        }
    }
}
