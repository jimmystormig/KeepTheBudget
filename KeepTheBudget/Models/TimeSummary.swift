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

    var dailyStatus: GoalStatus {
        dailyMinutes > dailyGoalMinutes ? .overGoal : .normal
    }

    var weeklyStatus: GoalStatus {
        weeklyMinutes > weeklyGoalMinutes ? .overGoal : .normal
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
}
