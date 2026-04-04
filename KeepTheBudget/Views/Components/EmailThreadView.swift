//
//  EmailThreadView.swift
//  KeepTheBudget
//
//  UI components for displaying email threads and messages
//

import SwiftUI

/// Displays an expandable email conversation thread
struct EmailThreadView: View {
    let thread: EmailThread
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

                    // Envelope icon
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                        .font(.body)

                    // Subject
                    Text(thread.displaySubject)
                        .font(.body)
                        .lineLimit(1)

                    Spacer()

                    // Message count badge
                    HStack(spacing: 4) {
                        if thread.sentCount > 0 {
                            Text("\(thread.sentCount)")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Image(systemName: "paperplane.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }

                        if thread.receivedCount > 0 {
                            if thread.sentCount > 0 {
                                Text("/")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("\(thread.receivedCount)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Image(systemName: "envelope.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
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
                    ForEach(thread.messages) { message in
                        EmailMessageRow(message: message)
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Displays a single email message within a thread
struct EmailMessageRow: View {
    let message: EmailMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Direction indicator
            Image(systemName: message.isSent ? "paperplane.fill" : "envelope.fill")
                .font(.caption)
                .foregroundColor(message.isSent ? .green : .blue)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                // From/To line
                HStack {
                    Text(message.from?.displayName ?? "(Unknown sender)")
                        .font(.caption)
                        .fontWeight(.medium)

                    if !message.to.isEmpty {
                        Text("→")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(message.to.map { $0.displayName }.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Timestamp
                    Text(formatTime(message.receivedDateTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Subject (if present and not empty)
                if let subject = message.subject, !subject.isEmpty {
                    Text(subject)
                        .font(.caption)
                        .lineLimit(1)
                }

                // Body preview
                if !message.safeBodyPreview.isEmpty {
                    Text(message.safeBodyPreview)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Attachment indicator
                if message.hasAttachments {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                        Text("Has attachments")
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
struct EmailThreadView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EmailThreadView(
                thread: sampleThread,
                isExpanded: true,
                onToggle: {}
            )

            EmailThreadView(
                thread: sampleThread,
                isExpanded: false,
                onToggle: {}
            )
        }
        .padding()
    }

    static let sampleThread: EmailThread = {
        let sender = EmailAddress(name: "John Doe", address: "john@example.com")
        let recipient1 = EmailAddress(name: "Jane Smith", address: "jane@example.com")
        let recipient2 = EmailAddress(name: "Bob Johnson", address: "bob@example.com")

        let message1 = EmailMessage(
            id: "1",
            subject: "Project Update",
            from: sender,
            to: [recipient1, recipient2],
            receivedDateTime: Date().addingTimeInterval(-3600),
            bodyPreview: "Here's the latest update on the project. We've made good progress...",
            conversationId: "conv-1",
            hasAttachments: true,
            isRead: true,
            isSent: true
        )

        let message2 = EmailMessage(
            id: "2",
            subject: "RE: Project Update",
            from: recipient1,
            to: [sender],
            receivedDateTime: Date().addingTimeInterval(-1800),
            bodyPreview: "Thanks for the update! Looks great. One question about...",
            conversationId: "conv-1",
            hasAttachments: false,
            isRead: false,
            isSent: false
        )

        return EmailThread(id: "conv-1", messages: [message1, message2])
    }()
}
#endif
