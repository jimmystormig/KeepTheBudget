//
//  DailyMeetingReportView.swift
//  KeepTheBudget
//
//  UI for daily meeting report with date/time range selection
//

import SwiftUI
import AppKit

struct DailyMeetingReportView: View {
    let defaultStartDate: Date
    let defaultEndDate: Date
    let onGenerateReport: (Date, Date) async -> ComprehensiveReport?
    let initialReport: ComprehensiveReport?
    let onClose: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var report: ComprehensiveReport?
    @State private var expandedFirstLevel: Set<UUID> = []
    @State private var expandedEmailThreads: Set<String> = []
    @State private var expandedChats: Set<String> = []
    @State private var showYesterdaySection = true
    @State private var showCalendarSection = true
    @State private var showEmailSection = false
    @State private var showChatSection = false
    @State private var showTodaySection = true
    @State private var showTodayCalendarSection = false
    @State private var showTodayEmailSection = false
    @State private var showTodayChatSection = false
    @State private var copiedToClipboard = false
    @State private var isGenerating = false
    @State private var errorMessage: String?

    init(
        defaultStartDate: Date,
        defaultEndDate: Date,
        onGenerateReport: @escaping (Date, Date) async -> ComprehensiveReport?,
        initialReport: ComprehensiveReport? = nil,
        onClose: @escaping () -> Void
    ) {
        self.defaultStartDate = defaultStartDate
        self.defaultEndDate = defaultEndDate
        self.onGenerateReport = onGenerateReport
        self.initialReport = initialReport
        self.onClose = onClose
        self._startDate = State(initialValue: defaultStartDate)
        self._endDate = State(initialValue: defaultEndDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date range selector with time pickers
            dateRangeSelectorView
                .padding(12)
                .goldenGateSurface(cornerRadius: 20)
                .padding([.horizontal, .top])

            Divider()

            // Report content or empty state
            if isGenerating {
                loadingView
            } else if let errorMessage = errorMessage {
                errorStateView(errorMessage)
            } else if let report = report {
                reportContentView(report)
            } else {
                emptyStateView
            }

            // Footer with Copy and Close buttons
            footerView
                .padding(10)
                .goldenGateSurface(cornerRadius: 20)
                .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 600, minHeight: 750)
        .reportZoomable()
        .onAppear {
            initializeOnAppear()
        }
    }

    // MARK: - Date Range Selector

    private var dateRangeSelectorView: some View {
        VStack(spacing: 12) {
            Text("Daily Meeting Report")
                .reportFont(.headline)

            HStack(spacing: 12) {
                Text("From:")
                    .foregroundStyle(Color.reportSecondary)

                DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .frame(width: 180)

                Text("To:")
                    .foregroundStyle(Color.reportSecondary)

                DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .frame(width: 180)

                Spacer()

                Button(action: generateReportForCurrentDates) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Generate")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isGenerating)
            }

            // Helpful hint
            Text("Defaults to 09:00 last workday → 09:00 today")
                .reportFont(.caption)
                .foregroundStyle(Color.reportSecondary)
        }
    }

    // MARK: - Report Content

    private func reportContentView(_ comprehensiveReport: ComprehensiveReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                reportHeaderView(comprehensiveReport.timeReport)

                historicalWorkSection(comprehensiveReport)

                if let remainingDayPlan = comprehensiveReport.remainingDayPlan {
                    remainingDaySection(remainingDayPlan)
                }
            }
            .padding()
            .textSelection(.enabled)
        }
    }

    private func reportHeaderView(_ report: TimeReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDateRange(start: report.startDate, end: report.endDate))
                .reportFont(.title3)
                .fontWeight(.semibold)

            HStack {
                Text("Total:")
                    .foregroundStyle(Color.reportSecondary)
                Text(TimeFormatter.format(minutes: report.totalMinutes))
                    .reportFont(.title3)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .goldenGateSurface(cornerRadius: 16)
    }

    private func calendarEventsSection(_ report: TimeReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (collapsible)
            Button(action: { showCalendarSection.toggle() }) {
                HStack {
                    Image(systemName: showCalendarSection ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)

                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("Calendar Events")
                        .reportFont(.headline)
                    Spacer()
                    if !report.firstLevelGroups.isEmpty {
                        Text("\(report.firstLevelGroups.count) groups")
                            .reportFont(.caption)
                            .foregroundStyle(Color.reportSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showCalendarSection {
                Divider()

                // First-level groups
                if report.firstLevelGroups.isEmpty {
                    Text("No events found in selected date range")
                        .foregroundStyle(Color.reportSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(report.firstLevelGroups) { firstLevel in
                        FirstLevelGroupView(
                            group: firstLevel,
                            isExpanded: expandedFirstLevel.contains(firstLevel.id),
                            onToggle: {
                                toggleExpansion(firstLevel.id)
                            }
                        )
                    }
                }
            }
        }
        .padding()
    }

    private func historicalWorkSection(_ report: ComprehensiveReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showYesterdaySection.toggle() }) {
                HStack {
                    Image(systemName: showYesterdaySection ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)

                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    Text("Yesterday's Work")
                        .reportFont(.headline)
                    Spacer()
                    Text(TimeFormatter.format(minutes: report.timeReport.totalMinutes))
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showYesterdaySection {
                Divider()
                calendarEventsSection(report.timeReport)
                emailThreadsSection(report.emailThreads)

                if let chats = report.chatConversations {
                    chatConversationsSection(chats)
                }
            }
        }
        .padding()
        .goldenGateSurface(cornerRadius: 20)
    }

    private func emailThreadsSection(_ threads: [EmailThread]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (collapsible)
            Button(action: { showEmailSection.toggle() }) {
                HStack {
                    Image(systemName: showEmailSection ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)

                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                    Text("Email Communications")
                        .reportFont(.headline)
                    Spacer()
                    if !threads.isEmpty {
                        Text("\(threads.count) threads")
                            .reportFont(.caption)
                            .foregroundStyle(Color.reportSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showEmailSection {
                Divider()

                // Thread list or empty state
                if threads.isEmpty {
                    Text("No emails in selected date range")
                        .foregroundStyle(Color.reportSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(threads) { thread in
                            EmailThreadView(
                                thread: thread,
                                isExpanded: expandedEmailThreads.contains(thread.id),
                                onToggle: { toggleEmailThread(thread.id) }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func chatConversationsSection(_ conversations: [ChatConversation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (collapsible)
            Button(action: { showChatSection.toggle() }) {
                HStack {
                    Image(systemName: showChatSection ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)

                    Image(systemName: "message.fill")
                        .foregroundColor(.purple)
                    Text("Teams Chats")
                        .reportFont(.headline)
                    Spacer()
                    if !conversations.isEmpty {
                        Text("\(conversations.count) conversations")
                            .reportFont(.caption)
                            .foregroundStyle(Color.reportSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showChatSection {
                Divider()

                // Conversation list or empty state
                if conversations.isEmpty {
                    Text("No Teams chats in selected date range")
                        .foregroundStyle(Color.reportSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(conversations) { conversation in
                            ChatConversationView(
                                conversation: conversation,
                                isExpanded: expandedChats.contains(conversation.id),
                                onToggle: { toggleChat(conversation.id) }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func remainingDaySection(_ plan: RemainingDayPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showTodaySection.toggle() }) {
                HStack {
                    Image(systemName: showTodaySection ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)

                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("What To Do Today")
                        .reportFont(.headline)
                    Spacer()
                    Text("\(plan.upcomingEvents.count + plan.unreadEmailThreads.count + plan.unreadChatConversations.count) buckets")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showTodaySection {
                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From \(formatTimestamp(plan.generatedAt)) to \(formatTimestamp(plan.endOfDay))")
                            .reportFont(.subheadline)
                            .fontWeight(.medium)
                    }

                    todayCalendarSection(plan.upcomingEvents)
                    todayUnreadEmailSection(plan.unreadEmailThreads)
                    todayUnreadChatSection(plan.unreadChatConversations)
                }
            }
        }
        .padding()
        .goldenGateSurface(cornerRadius: 20)
    }

    private func todayCalendarSection(_ events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showTodayCalendarSection.toggle() }) {
                HStack {
                    Image(systemName: showTodayCalendarSection ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)
                    Label("Upcoming Calendar Events", systemImage: "calendar")
                        .reportFont(.headline)
                    Spacer()
                    if !events.isEmpty {
                        Text("\(events.count) events")
                            .reportFont(.caption)
                            .foregroundStyle(Color.reportSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showTodayCalendarSection {
                if events.isEmpty {
                    Text("No remaining calendar events today")
                        .foregroundStyle(Color.reportSecondary)
                } else {
                    ForEach(events, id: \.id) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.subject)
                                .fontWeight(.medium)
                            Text(formatEventTimeRange(event))
                                .reportFont(.caption)
                                .foregroundStyle(Color.reportSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func todayUnreadEmailSection(_ threads: [EmailThread]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showTodayEmailSection.toggle() }) {
                HStack {
                    Image(systemName: showTodayEmailSection ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)
                    Label("Unread Email", systemImage: "envelope.fill")
                        .reportFont(.headline)
                    Spacer()
                    if !threads.isEmpty {
                        Text("\(threads.count) threads")
                            .reportFont(.caption)
                            .foregroundStyle(Color.reportSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showTodayEmailSection {
                if threads.isEmpty {
                    Text("No unread email")
                        .foregroundStyle(Color.reportSecondary)
                } else {
                    ForEach(threads) { thread in
                        EmailThreadView(
                            thread: thread,
                            isExpanded: expandedEmailThreads.contains(thread.id),
                            onToggle: { toggleEmailThread(thread.id) }
                        )
                    }
                }
            }
        }
    }

    private func todayUnreadChatSection(_ conversations: [ChatConversation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showTodayChatSection.toggle() }) {
                HStack {
                    Image(systemName: showTodayChatSection ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)
                    Label("Unread Teams Messages", systemImage: "message.fill")
                        .reportFont(.headline)
                    Spacer()
                    if !conversations.isEmpty {
                        Text("\(conversations.count) conversations")
                            .reportFont(.caption)
                            .foregroundStyle(Color.reportSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if showTodayChatSection {
                if conversations.isEmpty {
                    Text("No unread Teams messages")
                        .foregroundStyle(Color.reportSecondary)
                } else {
                    ForEach(conversations) { conversation in
                        ChatConversationView(
                            conversation: conversation,
                            isExpanded: expandedChats.contains(conversation.id),
                            onToggle: { toggleChat(conversation.id) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Loading and Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Generating report...")
                .foregroundStyle(Color.reportSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.reportSecondary)
            Text("Select a date range and click Generate")
                .foregroundStyle(Color.reportSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Error Generating Report")
                .reportFont(.headline)
            Text(message)
                .foregroundStyle(Color.reportSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button(action: copyToClipboard) {
                HStack(spacing: 6) {
                    Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                    Text(copiedToClipboard ? "Copied!" : "Copy to Clipboard")
                }
            }
            .disabled(report == nil || isGenerating)
            .buttonStyle(.glass)

            Spacer()

            Button("Close", action: onClose)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.glass)
        }
    }

    // MARK: - Helper Methods

    private func initializeOnAppear() {
        if let initialReport = initialReport {
            report = initialReport
            errorMessage = nil
            isGenerating = false

            expandedFirstLevel = Set(initialReport.timeReport.firstLevelGroups.map { $0.id })
            expandedEmailThreads = Set(initialReport.emailThreads.prefix(5).map { $0.id })
            if let chats = initialReport.chatConversations {
                expandedChats = Set(chats.prefix(5).map { $0.id })
            }

            return
        }

        generateReportForCurrentDates()
    }

    private func generateReportForCurrentDates() {
        print("🔄 DailyMeetingReportView: generateReportForCurrentDates() called")
        print("   Start: \(startDate)")
        print("   End: \(endDate)")

        Task {
            isGenerating = true
            errorMessage = nil
            report = nil

            print("   ⏳ Calling onGenerateReport callback...")

            let result = await onGenerateReport(startDate, endDate)

            if let result = result {
                print("   ✅ Report received with \(result.emailThreads.count) email threads")
                report = result
                // Auto-expand all groups when report is generated
                expandedFirstLevel = Set(result.timeReport.firstLevelGroups.map { $0.id })
                // Auto-expand first 5 email threads
                expandedEmailThreads = Set(result.emailThreads.prefix(5).map { $0.id })
                // Auto-expand first 5 chat conversations
                if let chats = result.chatConversations {
                    expandedChats = Set(chats.prefix(5).map { $0.id })
                }
            } else {
                print("   ❌ Report is nil! Check error dialog for details.")
                // Error dialog will be shown by AppDelegate
                errorMessage = "Report generation failed. See error dialog for details."
            }

            isGenerating = false
            print("   🏁 Generation complete")
        }
    }

    private func toggleExpansion(_ id: UUID) {
        if expandedFirstLevel.contains(id) {
            expandedFirstLevel.remove(id)
        } else {
            expandedFirstLevel.insert(id)
        }
    }

    private func toggleEmailThread(_ id: String) {
        if expandedEmailThreads.contains(id) {
            expandedEmailThreads.remove(id)
        } else {
            expandedEmailThreads.insert(id)
        }
    }

    private func toggleChat(_ id: String) {
        if expandedChats.contains(id) {
            expandedChats.remove(id)
        } else {
            expandedChats.insert(id)
        }
    }

    private func copyToClipboard() {
        guard let report = report else { return }
        let text = report.toText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedToClipboard = true

        // Reset feedback after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedToClipboard = false
        }
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        let startStr = formatter.string(from: start)

        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        if startYear == endYear {
            formatter.dateFormat = "MMM d, HH:mm yyyy"
        } else {
            formatter.dateFormat = "MMM d, HH:mm yyyy"
        }
        let endStr = formatter.string(from: end)

        return "\(startStr) - \(endStr)"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }

    private func formatEventTimeRange(_ event: CalendarEvent) -> String {
        if event.isAllDay {
            return "All day"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: event.start)) - \(formatter.string(from: event.end))"
    }
}
