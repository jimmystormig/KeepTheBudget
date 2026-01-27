//
//  TimeSummary.swift
//  KeepTheBudget
//
//  Represents daily and weekly time summaries with goal tracking
//

import Foundation

struct TimeSummary {
    let dailyMinutes: Int
    let weeklyMinutes: Int
    let dailyGoalMinutes: Int
    let weeklyGoalMinutes: Int
    let dailyCategoryMinutes: [String: Int]
    let weeklyCategoryMinutes: [String: Int]

    // Goal-eligible time (filtered by category preferences)
    let dailyGoalEligibleMinutes: Int
    let weeklyGoalEligibleMinutes: Int

    var dailyStatus: GoalStatus {
        dailyGoalEligibleMinutes > dailyGoalMinutes ? .overGoal : .normal
    }

    var weeklyStatus: GoalStatus {
        weeklyGoalEligibleMinutes > weeklyGoalMinutes ? .overGoal : .normal
    }

    var showWarning: Bool {
        dailyStatus == .overGoal || weeklyStatus == .overGoal
    }

    var dailyPercentage: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return Double(dailyMinutes) / Double(dailyGoalMinutes) * 100
    }

    var weeklyPercentage: Double {
        guard weeklyGoalMinutes > 0 else { return 0 }
        return Double(weeklyMinutes) / Double(weeklyGoalMinutes) * 100
    }

    var dailyGoalPercentage: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return Double(dailyGoalEligibleMinutes) / Double(dailyGoalMinutes) * 100
    }

    var weeklyGoalPercentage: Double {
        guard weeklyGoalMinutes > 0 else { return 0 }
        return Double(weeklyGoalEligibleMinutes) / Double(weeklyGoalMinutes) * 100
    }

    /// Categories sorted by daily time (descending)
    var categoriesSortedByDailyTime: [CategorySummary] {
        return dailyCategoryMinutes.map { category, minutes in
            CategorySummary(
                category: category,
                dailyMinutes: minutes,
                weeklyMinutes: weeklyCategoryMinutes[category] ?? 0
            )
        }
        .sorted { $0.dailyMinutes > $1.dailyMinutes }
    }

    /// Categories sorted by weekly time (descending)
    var categoriesSortedByWeeklyTime: [CategorySummary] {
        return weeklyCategoryMinutes.map { category, minutes in
            CategorySummary(
                category: category,
                dailyMinutes: dailyCategoryMinutes[category] ?? 0,
                weeklyMinutes: minutes
            )
        }
        .sorted { $0.weeklyMinutes > $1.weeklyMinutes }
    }
}
