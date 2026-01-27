//
//  CategoryBreakdownView.swift
//  KeepTheBudget
//
//  Displays collapsible category time breakdown
//

import SwiftUI

struct CategoryBreakdownView: View {
    let title: String  // "Today's Categories" or "This Week's Categories"
    let categories: [CategorySummary]
    let isDaily: Bool  // true = show dailyMinutes, false = show weeklyMinutes
    let goalEligibleCategories: Set<String>
    let categoryFilteringEnabled: Bool

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with expand/collapse button
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(categories.count) categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded category list
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(categories) { categorySummary in
                        HStack {
                            // Visual indicator for goal eligibility
                            if categoryFilteringEnabled {
                                Circle()
                                    .fill(isGoalEligible(categorySummary.category) ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                            }

                            Text(categorySummary.category)
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(TimeFormatter.format(
                                minutes: isDaily ? categorySummary.dailyMinutes : categorySummary.weeklyMinutes
                            ))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.leading, 20)
                        .help(categoryFilteringEnabled ?
                              (isGoalEligible(categorySummary.category) ?
                               "This category counts toward your goals" :
                               "Excluded from goals") :
                              "")
                    }
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private func isGoalEligible(_ category: String) -> Bool {
        goalEligibleCategories.contains(category)
    }
}
