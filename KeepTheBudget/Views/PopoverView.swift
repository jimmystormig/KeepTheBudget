//
//  PopoverView.swift
//  KeepTheBudget
//
//  Main popover menu displayed when clicking menu bar icon
//

import SwiftUI

struct PopoverView: View {
    let timeSummary: TimeSummary?
    let lastUpdateTime: Date?
    let isLoading: Bool
    let errorMessage: String?
    let preferences: AppPreferences
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void
    let onShowReport: () -> Void
    let onShowDailyReport: () -> Void
    let onQuit: () -> Void
    let onReauthenticate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 15) {
                if let summary = timeSummary {
                    // Daily summary
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Today:")
                                .font(.headline)
                            Spacer()
                            Text(TimeFormatter.format(minutes: summary.dailyGoalEligibleMinutes))
                                .font(.headline)
                                .foregroundColor(summary.dailyStatus == .overGoal ? .red : .primary)
                            Text("/ \(TimeFormatter.format(minutes: summary.dailyGoalMinutes))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Show total time if different from goal-eligible
                        if summary.dailyMinutes != summary.dailyGoalEligibleMinutes {
                            Text("Total: \(TimeFormatter.format(minutes: summary.dailyMinutes))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ProgressBar(
                            percentage: min(summary.dailyGoalPercentage, 100),
                            color: summary.dailyStatus == .overGoal ? .red : .blue
                        )

                        HStack {
                            Text("\(Int(summary.dailyGoalPercentage))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if summary.dailyStatus == .overGoal {
                                Text("Over Goal")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text("On Track")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }

                        // Daily categories (under Today section)
                        if !summary.dailyCategoryMinutes.isEmpty {
                            CategoryBreakdownView(
                                title: "Categories",
                                categories: summary.categoriesSortedByDailyTime,
                                isDaily: true,
                                goalEligibleCategories: preferences.goalEligibleCategories,
                                categoryFilteringEnabled: preferences.categoryFilteringEnabled
                            )
                            .padding(.top, 8)
                        }
                    }

                    Divider()

                    // Weekly summary
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("This Week:")
                                .font(.headline)
                            Spacer()
                            Text(TimeFormatter.format(minutes: summary.weeklyGoalEligibleMinutes))
                                .font(.headline)
                                .foregroundColor(summary.weeklyStatus == .overGoal ? .red : .primary)
                            Text("/ \(TimeFormatter.format(minutes: summary.weeklyGoalMinutes))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Show total time if different from goal-eligible
                        if summary.weeklyMinutes != summary.weeklyGoalEligibleMinutes {
                            Text("Total: \(TimeFormatter.format(minutes: summary.weeklyMinutes))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ProgressBar(
                            percentage: min(summary.weeklyGoalPercentage, 100),
                            color: summary.weeklyStatus == .overGoal ? .red : .blue
                        )

                        HStack {
                            Text("\(Int(summary.weeklyGoalPercentage))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if summary.weeklyStatus == .overGoal {
                                Text("Over Goal")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text("On Track")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }

                        // Weekly categories (under This Week section)
                        if !summary.weeklyCategoryMinutes.isEmpty {
                            CategoryBreakdownView(
                                title: "Categories",
                                categories: summary.categoriesSortedByWeeklyTime,
                                isDaily: false,
                                goalEligibleCategories: preferences.goalEligibleCategories,
                                categoryFilteringEnabled: preferences.categoryFilteringEnabled
                            )
                            .padding(.top, 8)
                        }
                    }
                } else if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading calendar data...")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let error = errorMessage {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        // Show "Sign In Again" button if error suggests authentication issue
                        if error.lowercased().contains("sign in") || error.lowercased().contains("expired") || error.lowercased().contains("session") {
                            Button(action: onReauthenticate) {
                                Text("Sign In Again")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 5)
                        }
                    }
                    .padding()
                }
            }
            .padding()

            Divider()

            // Status footer
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.caption)

                if let lastUpdate = lastUpdateTime {
                    Text("Updated \(TimeFormatter.formatRelativeTime(from: lastUpdate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Not updated yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))

            Divider()

            // Action buttons
            VStack(spacing: 0) {
                MenuButton(icon: "arrow.clockwise", title: "Refresh Now", action: onRefresh)
                Divider()
                MenuButton(icon: "doc.text", title: "Weekly Report", action: onShowReport)
                Divider()
                MenuButton(icon: "doc.text.magnifyingglass", title: "Daily Meeting Report", action: onShowDailyReport)
                Divider()
                MenuButton(icon: "gear", title: "Preferences", action: onOpenSettings)
                Divider()
                MenuButton(icon: "info.circle", title: "About", action: {
                    // TODO: Show about window
                })
                Divider()
                MenuButton(icon: "power", title: "Quit KeepTheBudget", action: onQuit)
            }
        }
        .frame(width: 300)
    }
}

struct MenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(isHovered ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
