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

    // MARK: - Email Messages

    func fetchEmails(from startDate: Date, to endDate: Date) async throws -> [EmailMessage] {
        print("📧 fetchEmails() called")
        print("   Start: \(startDate)")
        print("   End: \(endDate)")

        do {
            var allMessages: [EmailMessage] = []
            var nextLink: String? = nil
            var pageNumber = 1

            // Get user profile for sender filtering
            print("   👤 Fetching user profile for sender comparison...")
            let userProfile = try await fetchUserProfile()
            let userEmail = userProfile.mail
            print("   ✅ User email: \(userEmail)")

            repeat {
                let url: URL

                if let nextLink = nextLink, let nextURL = URL(string: nextLink) {
                    // Use pagination link
                    url = nextURL
                    print("   📄 Fetching email page \(pageNumber)...")
                } else {
                    // Build initial URL with query parameters
                    let baseURL = GraphConstants.messagesEndpoint
                    var components = URLComponents(string: baseURL)!

                    let startISO = startDate.toISO8601String()
                    let endISO = endDate.toISO8601String()

                    print("   📅 Start ISO: \(startISO)")
                    print("   📅 End ISO: \(endISO)")

                    components.queryItems = [
                        URLQueryItem(name: "$filter", value: "receivedDateTime ge \(startISO) and receivedDateTime le \(endISO)"),
                        URLQueryItem(name: "$select", value: "id,subject,from,toRecipients,receivedDateTime,bodyPreview,conversationId,hasAttachments,isRead"),
                        URLQueryItem(name: "$orderby", value: "receivedDateTime desc"),
                        URLQueryItem(name: "$top", value: "100") // Request up to 100 messages per page
                    ]

                    guard let initialURL = components.url else {
                        print("   ❌ Failed to build URL from components")
                        throw AppError.networkError("Invalid URL")
                    }
                    url = initialURL
                }

                print("   📡 Request URL: \(url.absoluteString)")

                let data: Data
                do {
                    print("   ⏳ Calling makeAuthenticatedRequest...")
                    data = try await makeAuthenticatedRequest(url: url)
                    print("   ✅ Got response data: \(data.count) bytes")
                } catch {
                    print("   ❌ makeAuthenticatedRequest failed: \(error)")
                    throw error
                }

                // Debug: Print and save raw JSON response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("   📋 Raw JSON response (first 500 chars):")
                    print(String(jsonString.prefix(500)))

                    // Save full response to file for debugging
                    let debugFile = "/tmp/graph_email_response.json"
                    try? jsonString.write(toFile: debugFile, atomically: true, encoding: .utf8)
                    print("   💾 Full response saved to: \(debugFile)")
                }

                let decoder = JSONDecoder()
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                let response: EmailListResponse
                do {
                    response = try decoder.decode(EmailListResponse.self, from: data)
                    print("   ✅ Successfully decoded \(response.value.count) messages")
                } catch {
                    print("   ❌ JSON Decoding failed: \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("      Missing key: \(key.stringValue)")
                            print("      Context: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("      Type mismatch: expected \(type)")
                            print("      Context: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("      Value not found: \(type)")
                            print("      Context: \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            print("      Data corrupted: \(context.debugDescription)")
                        @unknown default:
                            print("      Unknown decoding error")
                        }
                    }
                    throw error
                }

                // Mark messages as sent/received based on user email
                let messagesWithStatus = response.value.map { $0.withSentStatus(userEmail: userEmail) }

                print("   📦 Received \(messagesWithStatus.count) emails on page \(pageNumber)")
                allMessages.append(contentsOf: messagesWithStatus)

                // Check for next page
                nextLink = json?["@odata.nextLink"] as? String
                if nextLink != nil {
                    print("   ➡️  More emails available, fetching next page...")
                    pageNumber += 1
                }

            } while nextLink != nil

            print("   ✅ Total emails fetched: \(allMessages.count)")
            return allMessages
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

    func fetchUnreadInboxEmails() async throws -> [EmailMessage] {
        print("📧 fetchUnreadInboxEmails() called")

        do {
            let userProfile = try await fetchUserProfile()
            let userEmail = userProfile.mail

            var allMessages: [EmailMessage] = []
            var nextLink: String? = nil
            var pageNumber = 1

            repeat {
                let url: URL

                if let nextLink = nextLink, let nextURL = URL(string: nextLink) {
                    url = nextURL
                    print("   📄 Fetching unread email page \(pageNumber)...")
                } else {
                    var components = URLComponents(string: GraphConstants.mailFolderMessagesEndpoint(folderId: "inbox"))!
                    components.queryItems = [
                        URLQueryItem(name: "$filter", value: "isRead eq false"),
                        URLQueryItem(name: "$select", value: "id,subject,from,toRecipients,receivedDateTime,bodyPreview,conversationId,hasAttachments,isRead"),
                        URLQueryItem(name: "$orderby", value: "receivedDateTime desc"),
                        URLQueryItem(name: "$top", value: "100")
                    ]

                    guard let initialURL = components.url else {
                        throw AppError.networkError("Invalid URL")
                    }
                    url = initialURL
                }

                let data = try await makeAuthenticatedRequest(url: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let response = try JSONDecoder().decode(EmailListResponse.self, from: data)
                let messagesWithStatus = response.value.map { $0.withSentStatus(userEmail: userEmail) }

                allMessages.append(contentsOf: messagesWithStatus)
                nextLink = json?["@odata.nextLink"] as? String
                pageNumber += 1
            } while nextLink != nil

            print("   ✅ Total unread inbox emails fetched: \(allMessages.count)")
            return allMessages
        } catch let error as AppError {
            throw error
        } catch let error as AuthError {
            throw AppError.authenticationExpired
        } catch {
            let nsError = error as NSError
            if nsError.domain == "AuthManager" ||
               nsError.localizedDescription.lowercased().contains("account") ||
               nsError.localizedDescription.lowercased().contains("token") {
                throw AppError.authenticationExpired
            }
            throw AppError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Teams Chats

    func fetchChats(from startDate: Date, to endDate: Date) async throws -> [ChatConversation] {
        print("💬 fetchChats() called")
        print("   Start: \(startDate)")
        print("   End: \(endDate)")

        do {
            let allChats = try await fetchChatList()
            print("   ✅ Total chats fetched: \(allChats.count)")
            print("   📊 Checking all fetched chats for messages in date range")

            // Step 2: For each chat, fetch messages in date range
            var conversations: [ChatConversation] = []

            for chat in allChats {
                print("   💬 Fetching messages for chat: \(chat.id)")

                do {
                    let messages = try await fetchChatMessages(chatId: chat.id, from: startDate, to: endDate)

                    // Only include chats with messages in the date range
                    if !messages.isEmpty {
                        let chatType = ChatType(rawValue: chat.chatType) ?? .oneOnOne
                        let members = chat.members ?? []

                        let conversation = ChatConversation(
                            id: chat.id,
                            topic: chat.topic,
                            chatType: chatType,
                            messages: messages.sorted { $0.createdDateTime < $1.createdDateTime },
                            participants: members,
                            lastMessageDate: messages.map(\.createdDateTime).max() ?? Date()
                        )
                        conversations.append(conversation)
                        print("      ✅ Added conversation with \(messages.count) messages")
                    }
                } catch let error as AppError {
                    // Handle 403 Forbidden (user no longer member of chat) gracefully
                    if case .graphAPIError(let statusCode, _) = error, statusCode == 403 {
                        print("      ⚠️  Skipping chat (no longer a member): \(chat.topic ?? chat.id)")
                        continue
                    }
                    // Re-throw other errors
                    throw error
                } catch {
                    // Re-throw unexpected errors
                    throw error
                }
            }

            print("   ✅ Total conversations with messages: \(conversations.count)")
            return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }

        } catch let error as AppError {
            throw error
        } catch let error as AuthError {
            throw AppError.authenticationExpired
        } catch {
            let nsError = error as NSError
            if nsError.domain == "AuthManager" ||
               nsError.localizedDescription.lowercased().contains("account") ||
               nsError.localizedDescription.lowercased().contains("token") {
                throw AppError.authenticationExpired
            }
            throw AppError.networkError(error.localizedDescription)
        }
    }

    func fetchUnreadChats(asOf date: Date) async throws -> [ChatConversation] {
        print("💬 fetchUnreadChats() called")
        print("   As of: \(date)")

        do {
            let allChats = try await fetchChatList()
            var conversations: [ChatConversation] = []
            let earliestUnreadBoundary = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date.startOfDay

            for chat in allChats {
                let readMarker = chat.viewpoint?.lastMessageReadDateTime
                let fetchStart = max(readMarker ?? earliestUnreadBoundary, earliestUnreadBoundary)

                do {
                    let messages = try await fetchChatMessages(chatId: chat.id, from: fetchStart, to: date)
                    let unreadMessages = messages.filter { message in
                        guard let readMarker else { return true }
                        return message.createdDateTime > readMarker
                    }

                    guard !unreadMessages.isEmpty else { continue }

                    let conversation = ChatConversation(
                        id: chat.id,
                        topic: chat.topic,
                        chatType: ChatType(rawValue: chat.chatType) ?? .oneOnOne,
                        messages: unreadMessages.sorted { $0.createdDateTime < $1.createdDateTime },
                        participants: chat.members ?? [],
                        lastMessageDate: unreadMessages.map(\.createdDateTime).max() ?? date
                    )
                    conversations.append(conversation)
                } catch let error as AppError {
                    if case .graphAPIError(let statusCode, _) = error, statusCode == 403 {
                        print("      ⚠️  Skipping unread scan for chat (no longer a member): \(chat.topic ?? chat.id)")
                        continue
                    }
                    throw error
                }
            }

            print("   ✅ Total conversations with unread messages: \(conversations.count)")
            return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
        } catch let error as AppError {
            throw error
        } catch let error as AuthError {
            throw AppError.authenticationExpired
        } catch {
            let nsError = error as NSError
            if nsError.domain == "AuthManager" ||
               nsError.localizedDescription.lowercased().contains("account") ||
               nsError.localizedDescription.lowercased().contains("token") {
                throw AppError.authenticationExpired
            }
            throw AppError.networkError(error.localizedDescription)
        }
    }

    func fetchChatMessages(chatId: String, from startDate: Date, to endDate: Date) async throws -> [ChatMessage] {
        var allMessages: [ChatMessage] = []
        var nextLink: String? = nil
        var pageNumber = 1

        // Note: Graph API for chat messages does NOT support filtering by createdDateTime
        // We must fetch all messages and filter client-side

        repeat {
            let url: URL

            if let nextLink = nextLink, let nextURL = URL(string: nextLink) {
                url = nextURL
                print("      📄 Fetching message page \(pageNumber)...")
            } else {
                let baseURL = GraphConstants.chatMessagesEndpoint(chatId: chatId)
                var components = URLComponents(string: baseURL)!

                components.queryItems = [
                    URLQueryItem(name: "$orderby", value: "createdDateTime desc"),
                    URLQueryItem(name: "$top", value: "50")
                ]

                guard let initialURL = components.url else {
                    throw AppError.networkError("Invalid URL")
                }
                url = initialURL
            }

            let data = try await makeAuthenticatedRequest(url: url)

            // Debug: Save raw JSON for first page
            if pageNumber == 1, let jsonString = String(data: data, encoding: .utf8) {
                print("      📋 Raw message JSON (first 500 chars):")
                print(String(jsonString.prefix(500)))

                let debugFile = "/tmp/graph_chat_messages_response.json"
                try? jsonString.write(toFile: debugFile, atomically: true, encoding: .utf8)
                print("      💾 Full message response saved to: \(debugFile)")
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let response: ChatMessageListResponse
            do {
                response = try decoder.decode(ChatMessageListResponse.self, from: data)
                print("      ✅ Decoded \(response.value.count) messages")
            } catch {
                print("      ❌ Message JSON Decoding failed: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("         Missing key: \(key.stringValue)")
                        print("         Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))")
                    case .typeMismatch(let type, let context):
                        print("         Type mismatch: expected \(type)")
                        print("         Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))")
                    case .valueNotFound(let type, let context):
                        print("         Value not found: \(type)")
                        print("         Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))")
                    case .dataCorrupted(let context):
                        print("         Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("         Unknown decoding error")
                    }
                }
                throw error
            }

            // Add messages from this page
            for message in response.value {
                // Since we're fetching in reverse chronological order (newest first),
                // we can stop if we encounter a message older than our start date
                if message.createdDateTime < startDate {
                    print("      ⏹️  Reached messages before start date, stopping pagination")
                    return allMessages.filter { $0.createdDateTime >= startDate && $0.createdDateTime <= endDate }
                }

                // Only add messages within our date range
                if message.createdDateTime >= startDate && message.createdDateTime <= endDate {
                    allMessages.append(message)
                }
            }

            nextLink = json?["@odata.nextLink"] as? String
            if nextLink != nil {
                pageNumber += 1
            }

        } while nextLink != nil

        print("      📊 Found \(allMessages.count) messages within date range")
        return allMessages
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

    private func fetchChatList(limit: Int = 30) async throws -> [Chat] {
        var allChats: [Chat] = []
        var nextLink: String? = nil
        var pageNumber = 1

        print("   📋 Fetching chat list...")

        repeat {
            let url: URL

            if let nextLink = nextLink, let nextURL = URL(string: nextLink) {
                url = nextURL
                print("   📄 Fetching chat list page \(pageNumber)...")
            } else {
                let baseURL = GraphConstants.chatsEndpoint
                var components = URLComponents(string: baseURL)!

                components.queryItems = [
                    URLQueryItem(name: "$expand", value: "members"),
                    URLQueryItem(name: "$orderby", value: "lastMessagePreview/createdDateTime desc"),
                    URLQueryItem(name: "$top", value: "\(limit)")
                ]

                guard let initialURL = components.url else {
                    throw AppError.networkError("Invalid URL")
                }
                url = initialURL
            }

            print("   📡 Request URL: \(url.absoluteString)")

            let data = try await makeAuthenticatedRequest(url: url)
            print("   ✅ Got response data: \(data.count) bytes")

            if let jsonString = String(data: data, encoding: .utf8) {
                print("   📋 Raw JSON response (first 500 chars):")
                print(String(jsonString.prefix(500)))

                let debugFile = "/tmp/graph_chat_response.json"
                try? jsonString.write(toFile: debugFile, atomically: true, encoding: .utf8)
                print("   💾 Full response saved to: \(debugFile)")
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let response: ChatListResponse
            do {
                response = try decoder.decode(ChatListResponse.self, from: data)
                print("   ✅ Successfully decoded \(response.value.count) chats")
            } catch {
                print("   ❌ JSON Decoding failed: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("      Missing key: \(key.stringValue)")
                        print("      Context: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("      Type mismatch: expected \(type)")
                        print("      Context: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("      Value not found: \(type)")
                        print("      Context: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("      Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("      Unknown decoding error")
                    }
                }
                throw error
            }

            print("   📦 Received \(response.value.count) chats on page \(pageNumber)")
            allChats.append(contentsOf: response.value)

            if pageNumber == 1 {
                print("   ⏹️  Stopping after first page to optimize performance")
                break
            }

            nextLink = json?["@odata.nextLink"] as? String
            if nextLink != nil {
                print("   ➡️  More chats available, fetching next page...")
                pageNumber += 1
            }
        } while nextLink != nil

        return allChats
    }

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
