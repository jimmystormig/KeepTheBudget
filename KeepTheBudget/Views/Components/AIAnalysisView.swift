//
//  AIAnalysisView.swift
//  KeepTheBudget
//
//  Reusable component for AI-powered report analysis with Azure OpenAI
//

import SwiftUI

struct AIAnalysisView: View {
    let reportText: String
    let analyzer: AIReportAnalyzer
    let storageManager: StorageManager

    @Binding var analysis: AIReportAnalysis?
    @Binding var isAnalyzing: Bool
    @Binding var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Check if AI is configured
            if !isConfigured {
                notConfiguredView
            } else {
                // Show analysis state
                if isAnalyzing {
                    loadingView
                } else if let analysis = analysis, analysis.isSuccess {
                    successView(analysis)
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    idleView
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var isConfigured: Bool {
        storageManager.loadAzureOpenAIConfig()?.isConfigured ?? false
    }

    // MARK: - State Views

    private var notConfiguredView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)

            Text("AI Analysis Not Configured")
                .font(.headline)

            Text("Configure Azure OpenAI in Settings to enable AI-powered report analysis.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            Button(action: analyzeReport) {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                    Text("Analyze with AI")
                }
            }
            .buttonStyle(.borderedProminent)

            Text("Get AI-powered insights and highlights from this report")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Analyzing report...")
                .font(.headline)

            Text("This may take a few seconds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func successView(_ analysis: AIReportAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (fixed at top, not scrollable)
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("AI Analysis")
                    .font(.headline)

                Spacer()

                Button(action: analyzeReport) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Re-analyze")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 8)

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Yesterday's Work
                    if !analysis.yesterdayWork.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Yesterday's Work")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(Array(analysis.yesterdayWork.enumerated()), id: \.offset) { _, item in
                                Text("• \(item)")
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    // What To Do Today
                    if !analysis.todayWork.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What To Do Today")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            ForEach(Array(analysis.todayWork.enumerated()), id: \.offset) { _, item in
                                Text("• \(item)")
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    // Correlations (Phase 3)
                    if !analysis.correlations.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Correlations")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(analysis.correlations) { correlation in
                                    CorrelationRowView(correlation: correlation)
                                }
                            }
                        }
                    }

                    // Priorities (Phase 3)
                    if !analysis.priorities.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Priorities")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(analysis.priorities) { priority in
                                    PriorityRowView(priority: priority)
                                }
                            }
                        }
                    }

                    // Timestamp
                    Text("Generated at \(formatTimestamp(analysis.generatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .frame(maxHeight: 400)  // Limit height to ensure it's scrollable
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.red)

            Text("Analysis Failed")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: analyzeReport) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func analyzeReport() {
        guard !reportText.isEmpty else {
            errorMessage = "No report data to analyze"
            return
        }

        isAnalyzing = true
        errorMessage = nil
        analysis = nil

        Task {
            do {
                let result = try await analyzer.analyzeReport(reportText)
                await MainActor.run {
                    analysis = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Correlation Row View

struct CorrelationRowView: View {
    let correlation: Correlation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with type badge
            HStack(spacing: 8) {
                Image(systemName: correlation.type.icon)
                    .font(.body)
                    .foregroundColor(.purple)

                Text(correlation.type.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(4)

                Text(correlation.title)
                    .font(.body)
                    .fontWeight(.medium)
            }

            // Description
            Text(correlation.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Related items
            if !correlation.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(correlation.items, id: \.self) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(item)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Priority Row View

struct PriorityRowView: View {
    let priority: Priority

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with priority level badge
            HStack(spacing: 8) {
                Image(systemName: priority.level.icon)
                    .font(.body)
                    .foregroundColor(colorForLevel(priority.level))

                Text(priority.level.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForLevel(priority.level))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(colorForLevel(priority.level).opacity(0.15))
                    .cornerRadius(4)

                Text(priority.title)
                    .font(.body)
                    .fontWeight(.medium)
            }

            // Reason
            Text(priority.reason)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Related items
            if !priority.relatedItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(priority.relatedItems, id: \.self) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(item)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(12)
        .background(colorForLevel(priority.level).opacity(0.05))
        .cornerRadius(6)
    }

    private func colorForLevel(_ level: PriorityLevel) -> Color {
        switch level {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}
