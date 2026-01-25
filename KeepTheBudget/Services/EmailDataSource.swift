//
//  EmailDataSource.swift
//  KeepTheBudget
//
//  Email fetching and thread grouping service
//

import Foundation

/// Service for fetching and organizing email data from Microsoft Graph API
class EmailDataSource {
    private let graphAPIService: GraphAPIService
    private let storageManager: StorageManager

    init(graphAPIService: GraphAPIService, storageManager: StorageManager) {
        self.graphAPIService = graphAPIService
        self.storageManager = storageManager
    }

    /// Fetch and group emails into conversation threads for a date range
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    /// - Returns: Array of EmailThread objects sorted by most recent activity
    func fetchEmailThreads(from startDate: Date, to endDate: Date) async throws -> [EmailThread] {
        print("📧 EmailDataSource: Fetching emails from \(formatDate(startDate)) to \(formatDate(endDate))")

        // Fetch all emails in date range
        let emails = try await graphAPIService.fetchEmails(from: startDate, to: endDate)
        print("   Received \(emails.count) emails")

        // Group by conversationId
        let threadDict = Dictionary(grouping: emails) { $0.conversationId }
        print("   Grouped into \(threadDict.count) conversation threads")

        // Build EmailThread models
        let threads = threadDict.map { (conversationId, messages) in
            EmailThread(id: conversationId, messages: messages)
        }

        // Sort by most recent activity (newest first)
        let sortedThreads = threads.sorted { $0.lastDate > $1.lastDate }

        print("   ✅ Processed \(sortedThreads.count) email threads")
        return sortedThreads
    }

    /// Format date for logging
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
