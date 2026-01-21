//
//  GraphAPIService.swift
//  KeepTheBudget
//
//  Microsoft Graph API integration for calendar and user data
//

import Foundation

class GraphAPIService {
    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    // MARK: - User Profile

    func fetchUserProfile() async throws -> UserProfile {
        let url = URL(string: GraphConstants.meEndpoint)!
        let data = try await makeAuthenticatedRequest(url: url)

        let decoder = JSONDecoder()
        return try decoder.decode(UserProfile.self, from: data)
    }

    // MARK: - Calendars

    func fetchCalendars() async throws -> [CalendarInfo] {
        let url = URL(string: GraphConstants.calendarsEndpoint)!
        let data = try await makeAuthenticatedRequest(url: url)

        let decoder = JSONDecoder()
        let response = try decoder.decode(GraphCalendarsResponse.self, from: data)
        return response.value
    }

    // MARK: - Events

    func fetchEvents(calendarId: String, from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        var allEvents: [CalendarEvent] = []
        var nextLink: String? = nil
        var pageNumber = 1

        repeat {
            let url: URL

            if let nextLink = nextLink, let nextURL = URL(string: nextLink) {
                // Use pagination link
                url = nextURL
                print("   📄 Fetching page \(pageNumber)...")
            } else {
                // Build initial URL with query parameters
                let baseURL = GraphConstants.eventsEndpoint(calendarId: calendarId)
                var components = URLComponents(string: baseURL)!

                let startISO = startDate.toISO8601String()
                let endISO = endDate.toISO8601String()

                components.queryItems = [
                    URLQueryItem(name: "$filter", value: "start/dateTime ge '\(startISO)' and end/dateTime le '\(endISO)'"),
                    URLQueryItem(name: "$select", value: "id,subject,start,end,organizer,isAllDay"),
                    URLQueryItem(name: "$orderby", value: "start/dateTime"),
                    URLQueryItem(name: "$top", value: "100") // Request up to 100 events per page
                ]

                guard let initialURL = components.url else {
                    throw NSError(domain: "GraphAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                }
                url = initialURL
            }

            print("   📡 Request URL: \(url.absoluteString)")

            let data = try await makeAuthenticatedRequest(url: url)

            let decoder = JSONDecoder()
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let response = try decoder.decode(GraphEventResponse.self, from: data)
            let events = response.value.map { $0.toCalendarEvent() }

            print("   📦 Received \(events.count) events on page \(pageNumber)")
            allEvents.append(contentsOf: events)

            // Check for next page
            nextLink = json?["@odata.nextLink"] as? String
            if nextLink != nil {
                print("   ➡️  More events available, fetching next page...")
                pageNumber += 1
            }

        } while nextLink != nil

        print("   ✅ Total events fetched: \(allEvents.count)")
        return allEvents
    }

    // MARK: - Delta Query Support

    func fetchEventsWithDelta(calendarId: String, deltaLink: String?) async throws -> (events: [CalendarEvent], newDeltaLink: String?) {
        let url: URL

        if let deltaLink = deltaLink, let deltaURL = URL(string: deltaLink) {
            // Use existing delta link
            url = deltaURL
        } else {
            // Initial request - get all events with delta token
            let baseURL = GraphConstants.eventsEndpoint(calendarId: calendarId)
            var components = URLComponents(string: baseURL)!
            components.queryItems = [
                URLQueryItem(name: "$select", value: "id,subject,start,end,organizer,isAllDay"),
                URLQueryItem(name: "$orderby", value: "start/dateTime")
            ]
            guard let initialURL = components.url else {
                throw NSError(domain: "GraphAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            url = initialURL
        }

        let data = try await makeAuthenticatedRequest(url: url)

        let decoder = JSONDecoder()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Extract delta link if present
        let newDeltaLink = json?["@odata.deltaLink"] as? String

        // Parse events
        let response = try decoder.decode(GraphEventResponse.self, from: data)
        let events = response.value.map { $0.toCalendarEvent() }

        return (events, newDeltaLink)
    }

    // MARK: - Private Helpers

    private func makeAuthenticatedRequest(url: URL) async throws -> Data {
        print("   🔑 Getting access token...")
        // Get valid access token
        let accessToken = try await authManager.getValidAccessToken()
        print("   ✅ Access token obtained")

        // Create request with timeout
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30 // 30 second timeout
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("   📤 Sending request...")
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        print("   📥 Received response")

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("   ❌ Invalid response type")
            throw NSError(domain: "GraphAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        print("   📊 HTTP Status: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("   ❌ HTTP Error: \(errorMessage)")
            throw NSError(domain: "GraphAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"])
        }

        print("   ✅ Request successful, data size: \(data.count) bytes")
        return data
    }
}

// MARK: - Response Models

struct GraphCalendarsResponse: Codable {
    let value: [CalendarInfo]
}
