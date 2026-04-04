//
//  ChatDataSource.swift
//  KeepTheBudget
//
//  Service for fetching and managing Teams chat conversations
//

import Foundation

class ChatDataSource {
    private let graphAPIService: GraphAPIService
    private let storageManager: StorageManager

    init(graphAPIService: GraphAPIService, storageManager: StorageManager) {
        self.graphAPIService = graphAPIService
        self.storageManager = storageManager
    }

    /// Fetch chat conversations with messages in the specified date range
    func fetchChatConversations(from startDate: Date, to endDate: Date) async throws -> [ChatConversation] {
        print("💬 ChatDataSource.fetchChatConversations()")
        print("   Date range: \(startDate) to \(endDate)")

        // Fetch all chats with messages in the date range
        let conversations = try await graphAPIService.fetchChats(from: startDate, to: endDate)

        print("   ✅ Found \(conversations.count) conversations with messages")

        // Sort by most recent activity
        return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    /// Fetch unread chat conversations as of the provided moment
    func fetchUnreadChatConversations(asOf date: Date) async throws -> [ChatConversation] {
        print("💬 ChatDataSource.fetchUnreadChatConversations()")
        print("   As of: \(date)")

        let conversations = try await graphAPIService.fetchUnreadChats(asOf: date)

        print("   ✅ Found \(conversations.count) conversations with unread messages")
        return conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }
}
