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

    @State private var analysis: AIReportAnalysis?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

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
        VStack(alignment: .leading, spacing: 16) {
            // Header
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

            Divider()

            // Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Text(analysis.summary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Highlights
            if !analysis.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Highlights")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(analysis.highlights.enumerated()), id: \.offset) { index, highlight in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.blue)
                                Text(highlight)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            // Timestamp
            Text("Generated \(formatTimestamp(analysis.generatedAt))")
                .font(.caption2)
                .foregroundColor(.secondary)
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
