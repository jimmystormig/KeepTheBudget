//
//  DailyMeetingReportView.swift
//  KeepTheBudget
//
//  UI for daily meeting report with date/time range selection and AI analysis
//

import SwiftUI
import AppKit

struct DailyMeetingReportView: View {
    let defaultStartDate: Date
    let defaultEndDate: Date
    let onGenerateReport: (Date, Date) async -> ComprehensiveReport?
    let aiAnalyzer: AIReportAnalyzer
    let storageManager: StorageManager
    let initialReport: ComprehensiveReport?
    let initialAIAnalysis: AIReportAnalysis?
    let initialAIErrorMessage: String?
    let autoRunAIOnAppear: Bool
    let onClose: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var report: ComprehensiveReport?
    @State private var expandedFirstLevel: Set<UUID> = []
    @State private var expandedEmailThreads: Set<String> = []
    @State private var expandedChats: Set<String> = []
    @State private var showCalendarSection = true
    @State private var showEmailSection = true
    @State private var showChatSection = true
    @State private var copiedToClipboard = false
    @State private var isGenerating = false
    @State private var showAISection = false
    @State private var errorMessage: String?

    // AI Analysis state (lifted up to persist across collapse/expand)
    @State private var aiAnalysis: AIReportAnalysis?
    @State private var isAnalyzingAI = false
    @State private var aiErrorMessage: String?
    @State private var didRunAutoAIOnAppear = false

    init(
        defaultStartDate: Date,
        defaultEndDate: Date,
        onGenerateReport: @escaping (Date, Date) async -> ComprehensiveReport?,
        aiAnalyzer: AIReportAnalyzer,
        storageManager: StorageManager,
        initialReport: ComprehensiveReport? = nil,
        initialAIAnalysis: AIReportAnalysis? = nil,
        initialAIErrorMessage: String? = nil,
        autoRunAIOnAppear: Bool = false,
        onClose: @escaping () -> Void
    ) {
        self.defaultStartDate = defaultStartDate
        self.defaultEndDate = defaultEndDate
        self.onGenerateReport = onGenerateReport
        self.aiAnalyzer = aiAnalyzer
        self.storageManager = storageManager
        self.initialReport = initialReport
        self.initialAIAnalysis = initialAIAnalysis
        self.initialAIErrorMessage = initialAIErrorMessage
        self.autoRunAIOnAppear = autoRunAIOnAppear
        self.onClose = onClose
        self._startDate = State(initialValue: defaultStartDate)
        self._endDate = State(initialValue: defaultEndDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date range selector with time pickers
            dateRangeSelectorView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

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

            Divider()

            // AI Analysis section (collapsible)
            if report != nil {
                aiAnalysisSection
                Divider()
            }

            // Footer with Copy and Close buttons
            footerView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 750)
        .onAppear {
            initializeOnAppear()
        }
    }

    // MARK: - Date Range Selector

    private var dateRangeSelectorView: some View {
        VStack(spacing: 12) {
            Text("Daily Meeting Report")
                .font(.headline)

            HStack(spacing: 12) {
                Text("From:")
                    .foregroundColor(.secondary)

                DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .frame(width: 180)

                Text("To:")
                    .foregroundColor(.secondary)

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
                .disabled(isGenerating)
            }

            // Helpful hint
            Text("Defaults to 09:00 last workday → 09:00 today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Report Content

    private func reportContentView(_ comprehensiveReport: ComprehensiveReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                reportHeaderView(comprehensiveReport.timeReport)

                // Calendar Events Section
                calendarEventsSection(comprehensiveReport.timeReport)

                // Email Threads Section
                emailThreadsSection(comprehensiveReport.emailThreads)

                // Teams Chats Section
                if let chats = comprehensiveReport.chatConversations {
                    chatConversationsSection(chats)
                }
            }
            .padding()
            .textSelection(.enabled)
        }
    }

    private func reportHeaderView(_ report: TimeReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDateRange(start: report.startDate, end: report.endDate))
                .font(.title3)
                .fontWeight(.semibold)

            HStack {
                Text("Total:")
                    .foregroundColor(.secondary)
                Text(TimeFormatter.format(minutes: report.totalMinutes))
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func calendarEventsSection(_ report: TimeReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (collapsible)
            Button(action: { showCalendarSection.toggle() }) {
                HStack {
                    Image(systemName: showCalendarSection ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("Calendar Events")
                        .font(.headline)
                    Spacer()
                    if !report.firstLevelGroups.isEmpty {
                        Text("\(report.firstLevelGroups.count) groups")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
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
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private func emailThreadsSection(_ threads: [EmailThread]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (collapsible)
            Button(action: { showEmailSection.toggle() }) {
                HStack {
                    Image(systemName: showEmailSection ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Image(systemName: "envelope.fill")
                        .foregroundColor(.blue)
                    Text("Email Communications")
                        .font(.headline)
                    Spacer()
                    if !threads.isEmpty {
                        Text("\(threads.count) threads")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
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
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private func chatConversationsSection(_ conversations: [ChatConversation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (collapsible)
            Button(action: { showChatSection.toggle() }) {
                HStack {
                    Image(systemName: showChatSection ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Image(systemName: "message.fill")
                        .foregroundColor(.purple)
                    Text("Teams Chats")
                        .font(.headline)
                    Spacer()
                    if !conversations.isEmpty {
                        Text("\(conversations.count) conversations")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
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
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - AI Analysis Section

    private var aiAnalysisSection: some View {
        DisclosureGroup(
            isExpanded: $showAISection,
            content: {
                if let report = report {
                    AIAnalysisView(
                        reportText: report.toText(),
                        analyzer: aiAnalyzer,
                        storageManager: storageManager,
                        analysis: $aiAnalysis,
                        isAnalyzing: $isAnalyzingAI,
                        errorMessage: $aiErrorMessage
                    )
                    .padding(.top, 8)
                }
            },
            label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                    Text("AI Analysis")
                        .font(.headline)
                }
                .padding(.vertical, 8)
            }
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Loading and Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Generating report...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a date range and click Generate")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Error Generating Report")
                .font(.headline)
            Text(message)
                .foregroundColor(.secondary)
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

            Spacer()

            Button("Close", action: onClose)
                .keyboardShortcut(.cancelAction)
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

            aiAnalysis = initialAIAnalysis
            aiErrorMessage = initialAIErrorMessage
            showAISection = initialAIAnalysis != nil || initialAIErrorMessage != nil || autoRunAIOnAppear

            if autoRunAIOnAppear && initialAIAnalysis == nil && !didRunAutoAIOnAppear {
                didRunAutoAIOnAppear = true
                runAIAnalysisForCurrentReport()
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

            // Clear previous AI analysis when generating new report
            aiAnalysis = nil
            isAnalyzingAI = false
            aiErrorMessage = nil

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

    private func runAIAnalysisForCurrentReport() {
        guard let report = report else { return }
        let reportText = report.toText()
        guard !reportText.isEmpty else {
            aiErrorMessage = "No report data to analyze"
            return
        }

        isAnalyzingAI = true
        aiErrorMessage = nil
        aiAnalysis = nil

        Task {
            do {
                let result = try await aiAnalyzer.analyzeReport(reportText)
                await MainActor.run {
                    aiAnalysis = result
                    isAnalyzingAI = false
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = error.localizedDescription
                    isAnalyzingAI = false
                }
            }
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
}
