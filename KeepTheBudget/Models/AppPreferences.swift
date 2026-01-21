//
//  AppPreferences.swift
//  KeepTheBudget
//
//  User preferences and configuration
//

import Foundation

struct AppPreferences: Codable, Equatable {
    var selectedCalendarId: String?
    var dailyGoalMinutes: Int = 480 // 8 hours default
    var weeklyGoalMinutes: Int = 2400 // 40 hours default
    var refreshIntervalMinutes: Int = 10

    var dailyGoalHours: Int {
        get { dailyGoalMinutes / 60 }
        set { dailyGoalMinutes = newValue * 60 + (dailyGoalMinutes % 60) }
    }

    var dailyGoalRemainingMinutes: Int {
        get { dailyGoalMinutes % 60 }
        set { dailyGoalMinutes = (dailyGoalMinutes / 60) * 60 + newValue }
    }

    var weeklyGoalHours: Int {
        get { weeklyGoalMinutes / 60 }
        set { weeklyGoalMinutes = newValue * 60 + (weeklyGoalMinutes % 60) }
    }

    var weeklyGoalRemainingMinutes: Int {
        get { weeklyGoalMinutes % 60 }
        set { weeklyGoalMinutes = (weeklyGoalMinutes / 60) * 60 + newValue }
    }
}
