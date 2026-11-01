//
//  WeeklyReportView.swift
//  KeepTheBudget
//
//  UI for displaying hierarchical weekly time report with date range selection
//

import SwiftUI
import AppKit

struct WeeklyReportView: View {
    let defaultStartDate: Date
    let defaultEndDate: Date
    let onGenerateReport: (Date, Date) async -> TimeReport?
    let onClose: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var report: TimeReport?
    @State private var expandedFirstLevel: Set<UUID> = []
    @State private var copiedToClipboard = false
    @State private var isGenerating = false

    init(
        defaultStartDate: Date,
        defaultEndDate: Date,
        onGenerateReport: @escaping (Date, Date) async -> TimeReport?,
        onClose: @escaping () -> Void
    ) {
        self.defaultStartDate = defaultStartDate
        self.defaultEndDate = defaultEndDate
        self.onGenerateReport = onGenerateReport
        self.onClose = onClose
        self._startDate = State(initialValue: defaultStartDate)
        self._endDate = State(initialValue: defaultEndDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date range selector
            dateRangeSelectorView
                .padding(12)
                .goldenGateSurface(cornerRadius: 20)
                .padding([.horizontal, .top])

            Divider()

            // Report content or empty state
            if isGenerating {
                loadingView
            } else if let report = report {
                reportContentView(report)
            } else {
                emptyStateView
            }

            Divider()

            // Footer with Copy and Close buttons
            footerView
                .padding(10)
                .goldenGateSurface(cornerRadius: 20)
                .padding([.horizontal, .bottom])
        }
        .frame(minWidth: 550, minHeight: 650)
        .reportZoomable()
        .onAppear {
            generateReportForCurrentDates()
        }
    }

    // MARK: - Date Range Selector

    private var dateRangeSelectorView: some View {
        HStack(spacing: 12) {
            Text("From:")
                .foregroundStyle(Color.reportSecondary)

            DatePicker("", selection: $startDate, displayedComponents: .date)
                .labelsHidden()
                .frame(width: 130)

            Text("To:")
                .foregroundStyle(Color.reportSecondary)

            DatePicker("", selection: $endDate, displayedComponents: .date)
                .labelsHidden()
                .frame(width: 130)

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
    }

    // MARK: - Report Content

    private func reportContentView(_ report: TimeReport) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                reportHeaderView(report)

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
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(Color.reportSecondary)
            Text("Select a date range and click Generate")
                .foregroundStyle(Color.reportSecondary)
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

    private func generateReportForCurrentDates() {
        Task {
            isGenerating = true
            report = await onGenerateReport(startDate, endDate)

            // Auto-expand all groups when report is generated
            if let report = report {
                expandedFirstLevel = Set(report.firstLevelGroups.map { $0.id })
            }

            isGenerating = false
        }
    }

    private func toggleExpansion(_ id: UUID) {
        if expandedFirstLevel.contains(id) {
            expandedFirstLevel.remove(id)
        } else {
            expandedFirstLevel.insert(id)
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
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: start)

        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)

        if startYear == endYear {
            formatter.dateFormat = "MMM d, yyyy"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        let endStr = formatter.string(from: end)

        return "Week of \(startStr) - \(endStr)"
    }
}

// MARK: - First Level Group View

struct FirstLevelGroupView: View {
    let group: FirstLevelGroup
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with chevron
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .reportFont(.caption)
                        .foregroundStyle(Color.reportSecondary)
                        .frame(width: 12)

                    Text(group.name)
                        .reportFont(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("(\(TimeFormatter.format(minutes: group.totalMinutes)))")
                        .reportFont(.body)
                        .foregroundStyle(Color.reportSecondary)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Second-level groups (when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(group.secondLevelGroups) { secondLevel in
                        SecondLevelGroupView(group: secondLevel)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(12)
        .goldenGateSurface(cornerRadius: 16)
    }
}

// MARK: - Second Level Group View

struct SecondLevelGroupView: View {
    let group: SecondLevelGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Second level name and time
            HStack {
                Text("- \(group.name)")
                    .reportFont(.body)
                    .fontWeight(.medium)

                Text("(\(TimeFormatter.format(minutes: group.roundedMinutes)))")
                    .reportFont(.body)
                    .foregroundStyle(Color.reportSecondary)
            }

            // Descriptions as bullet points
            if !group.descriptions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(group.descriptions, id: \.self) { description in
                        Text("• \(description)")
                            .reportFont(.body)
                            .foregroundStyle(Color.reportSecondary)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }
}
