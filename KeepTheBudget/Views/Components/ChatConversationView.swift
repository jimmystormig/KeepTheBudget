//
//  ChatConversationView.swift
//  KeepTheBudget
//
//  UI components for displaying Teams chat conversations
//

import SwiftUI

/// Displays an expandable Teams chat conversation
struct ChatConversationView: View {
    let conversation: ChatConversation
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header button
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    // Chevron indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    // Chat icon
                    Image(systemName: chatIcon)
                        .foregroundColor(chatColor)
                        .font(.body)

                    // Chat name
                    Text(conversation.displayName)
                        .font(.body)
                        .lineLimit(1)

                    Spacer()

                    // Message count badge
                    HStack(spacing: 4) {
                        Text("\(conversation.totalMessages)")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Image(systemName: "message.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)

                    // Chat type badge
                    Text(conversation.chatType.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content: message list
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(conversation.messages) { message in
                        ChatMessageRow(message: message)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }

    /// Icon based on chat type
    private var chatIcon: String {
        switch conversation.chatType {
        case .oneOnOne:
            return "bubble.left.and.bubble.right.fill"
        case .group:
            return "person.3.fill"
        case .meeting:
            return "video.fill"
        }
    }

    /// Color based on chat type
    private var chatColor: Color {
        switch conversation.chatType {
        case .oneOnOne:
            return .purple
        case .group:
            return .blue
        case .meeting:
            return .orange
        }
    }
}

/// Displays a single chat message
struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Message icon
            Image(systemName: "message.fill")
                .font(.caption)
                .foregroundColor(.purple)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                // Sender and timestamp
                HStack {
                    Text(message.from?.safeDisplayName ?? "(System message)")
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    // Timestamp
                    Text(formatTime(message.createdDateTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Message body
                if !message.displayBody.isEmpty && message.displayBody != "(Empty message)" {
                    Text(message.displayBody)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)  // Allow full height expansion
                }

                // Message type indicator (if not standard message)
                if message.messageType != "message" {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                        Text(message.messageType)
                            .font(.caption2)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }

    /// Format message timestamp relative to current date
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEE HH:mm"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }

        return formatter.string(from: date)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct ChatConversationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChatConversationView(
                conversation: sampleConversation,
                isExpanded: true,
                onToggle: {}
            )

            ChatConversationView(
                conversation: sampleConversation,
                isExpanded: false,
                onToggle: {}
            )
        }
        .padding()
    }

    static let sampleConversation: ChatConversation = {
        let participant1 = ChatParticipant(id: "1", displayName: "John Doe", email: "john@example.com")
        let participant2 = ChatParticipant(id: "2", displayName: "Jane Smith", email: "jane@example.com")

        let message1 = ChatMessage(
            id: "1",
            from: participant1,
            body: "Hi team, let's discuss the project timeline",
            createdDateTime: Date().addingTimeInterval(-3600),
            messageType: "message"
        )

        let message2 = ChatMessage(
            id: "2",
            from: participant2,
            body: "Sure! I think we can finish by next week",
            createdDateTime: Date().addingTimeInterval(-1800),
            messageType: "message"
        )

        return ChatConversation(
            id: "chat-1",
            topic: "Project Timeline Discussion",
            chatType: .group,
            messages: [message1, message2],
            participants: [participant1, participant2],
            lastMessageDate: message2.createdDateTime
        )
    }()
}
#endif
