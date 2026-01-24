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
        do {
            let url = URL(string: GraphConstants.meEndpoint)!
            let data = try await makeAuthenticatedRequest(url: url)

            let decoder = JSONDecoder()
            return try decoder.decode(UserProfile.self, from: data)
        } catch let error as AppError {
            print("   📤 GraphAPIService: Passing through AppError: \(error.errorDescription ?? "unknown")")
            // Pass through AppError unchanged
            throw error
        } catch let error as AuthError {
            print("   🔐 GraphAPIService: Caught AuthError, converting to authenticationExpired")
            // Convert auth errors to authentication expired
            throw AppError.authenticationExpired
        } catch {
            // Check if this is an auth-related NSError
            let nsError = error as NSError
            print("   ⚠️  GraphAPIService: Caught generic error")
            print("       Type: \(type(of: error))")
            print("       Domain: \(nsError.domain)")
            print("       Description: \(error.localizedDescription)")

            if nsError.domain == "AuthManager" ||
               nsError.localizedDescription.lowercased().contains("account") ||
               nsError.localizedDescription.lowercased().contains("token") {
                print("   🔐 GraphAPIService: Detected auth-related error, converting to authenticationExpired")
                throw AppError.authenticationExpired
            }
            print("   🌐 GraphAPIService: Converting to network error")
            // Convert other errors to network error
            throw AppError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Calendars

    func fetchCalendars() async throws -> [CalendarInfo] {
        do {
            let url = URL(string: GraphConstants.calendarsEndpoint)!
            let data = try await makeAuthenticatedRequest(url: url)

            let decoder = JSONDecoder()
            let response = try decoder.decode(GraphCalendarsResponse.self, from: data)
            return response.value
        } catch let error as AppError {
            // Pass through AppError unchanged
            throw error
        } catch let error as AuthError {
            // Convert auth errors to authentication expired
            throw AppError.authenticationExpired
        } catch {
            // Check if this is an auth-related NSError
            let nsError = error as NSError
            if nsError.domain == "AuthManager" ||
               nsError.localizedDescription.lowercased().contains("account") ||
               nsError.localizedDescription.lowercased().contains("token") {
                throw AppError.authenticationExpired
            }
            // Convert other errors to network error
            throw AppError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Events

    func fetchEvents(calendarId: String, from startDate: Date, to endDate: Date) async throws -> [CalendarEvent] {
        do {
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
                        throw AppError.networkError("Invalid URL")
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
        } catch let error as AppError {
            // Pass through AppError unchanged
            throw error
        } catch let error as AuthError {
            // Convert auth errors to authentication expired
            throw AppError.authenticationExpired
        } catch {
            // Check if this is an auth-related NSError
            let nsError = error as NSError
            if nsError.domain == "AuthManager" ||
               nsError.localizedDescription.lowercased().contains("account") ||
               nsError.localizedDescription.lowercased().contains("token") {
                throw AppError.authenticationExpired
            }
            // Convert other errors to network error
            throw AppError.networkError(error.localizedDescription)
        }
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

    private func makeAuthenticatedRequest(url: URL, isRetry: Bool = false) async throws -> Data {
        print("   🔑 Getting access token...")
        // Get valid access token
        let accessToken: String
        do {
            accessToken = try await authManager.getValidAccessToken()
            print("   ✅ Access token obtained")
        } catch {
            // ANY error from getValidAccessToken is an authentication issue
            print("   ⚠️  makeAuthenticatedRequest: Caught error from getValidAccessToken")
            print("       Error type: \(type(of: error))")
            print("       Error description: \(error.localizedDescription)")
            print("   🔐 Converting ALL token errors to authenticationExpired")
            throw AppError.authenticationExpired
        }

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
            throw AppError.networkError("Invalid response from server")
        }

        print("   📊 HTTP Status: \(httpResponse.statusCode)")

        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            print("   ✅ Request successful, data size: \(data.count) bytes")
            return data

        case 401:
            // Token expired or invalid
            print("   🔐 HTTP 401: Token expired or invalid")

            if isRetry {
                // Already retried once, give up
                print("   ❌ Retry failed, token refresh didn't help")
                authManager.invalidateCachedToken()
                throw AppError.authenticationExpired
            }

            // Attempt token refresh and retry
            print("   🔄 Attempting token refresh and retry...")
            do {
                _ = try await authManager.forceTokenRefresh()
                print("   ✅ Token refreshed, retrying request...")
                return try await makeAuthenticatedRequest(url: url, isRetry: true)
            } catch {
                print("   ❌ Token refresh failed: \(error.localizedDescription)")
                throw AppError.authenticationExpired
            }

        default:
            // Other HTTP errors
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("   ❌ HTTP Error \(httpResponse.statusCode): \(errorMessage)")
            throw AppError.graphAPIError(httpResponse.statusCode, errorMessage)
        }
    }
}

// MARK: - Response Models

struct GraphCalendarsResponse: Codable {
    let value: [CalendarInfo]
}
