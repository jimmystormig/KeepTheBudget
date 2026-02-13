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

    // Category-based goal filtering
    var categoryFilteringEnabled: Bool = false
    var goalEligibleCategories: Set<String> = []
    var includeUncategorizedInGoals: Bool = false

    // Auto daily report scheduling
    var autoDailyReportEnabled: Bool = true
    var autoDailyReportHour: Int = 8
    var autoDailyReportMinute: Int = 45
    var autoDailyReportWeekdaysOnly: Bool = true
    var autoDailyReportIncludeAI: Bool = true
    var autoDailyReportAutoOpenWindow: Bool = true
    var lastAutoDailyReportRunDate: Date? = nil

    enum CodingKeys: String, CodingKey {
        case selectedCalendarId
        case dailyGoalMinutes
        case weeklyGoalMinutes
        case refreshIntervalMinutes
        case categoryFilteringEnabled
        case goalEligibleCategories
        case includeUncategorizedInGoals
        case autoDailyReportEnabled
        case autoDailyReportHour
        case autoDailyReportMinute
        case autoDailyReportWeekdaysOnly
        case autoDailyReportIncludeAI
        case autoDailyReportAutoOpenWindow
        case lastAutoDailyReportRunDate
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedCalendarId = try container.decodeIfPresent(String.self, forKey: .selectedCalendarId)
        dailyGoalMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyGoalMinutes) ?? 480
        weeklyGoalMinutes = try container.decodeIfPresent(Int.self, forKey: .weeklyGoalMinutes) ?? 2400
        refreshIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalMinutes) ?? 10
        categoryFilteringEnabled = try container.decodeIfPresent(Bool.self, forKey: .categoryFilteringEnabled) ?? false
        goalEligibleCategories = try container.decodeIfPresent(Set<String>.self, forKey: .goalEligibleCategories) ?? []
        includeUncategorizedInGoals = try container.decodeIfPresent(Bool.self, forKey: .includeUncategorizedInGoals) ?? false
        autoDailyReportEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoDailyReportEnabled) ?? true
        autoDailyReportHour = try container.decodeIfPresent(Int.self, forKey: .autoDailyReportHour) ?? 8
        autoDailyReportMinute = try container.decodeIfPresent(Int.self, forKey: .autoDailyReportMinute) ?? 45
        autoDailyReportWeekdaysOnly = try container.decodeIfPresent(Bool.self, forKey: .autoDailyReportWeekdaysOnly) ?? true
        autoDailyReportIncludeAI = try container.decodeIfPresent(Bool.self, forKey: .autoDailyReportIncludeAI) ?? true
        autoDailyReportAutoOpenWindow = try container.decodeIfPresent(Bool.self, forKey: .autoDailyReportAutoOpenWindow) ?? true
        lastAutoDailyReportRunDate = try container.decodeIfPresent(Date.self, forKey: .lastAutoDailyReportRunDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selectedCalendarId, forKey: .selectedCalendarId)
        try container.encode(dailyGoalMinutes, forKey: .dailyGoalMinutes)
        try container.encode(weeklyGoalMinutes, forKey: .weeklyGoalMinutes)
        try container.encode(refreshIntervalMinutes, forKey: .refreshIntervalMinutes)
        try container.encode(categoryFilteringEnabled, forKey: .categoryFilteringEnabled)
        try container.encode(goalEligibleCategories, forKey: .goalEligibleCategories)
        try container.encode(includeUncategorizedInGoals, forKey: .includeUncategorizedInGoals)
        try container.encode(autoDailyReportEnabled, forKey: .autoDailyReportEnabled)
        try container.encode(autoDailyReportHour, forKey: .autoDailyReportHour)
        try container.encode(autoDailyReportMinute, forKey: .autoDailyReportMinute)
        try container.encode(autoDailyReportWeekdaysOnly, forKey: .autoDailyReportWeekdaysOnly)
        try container.encode(autoDailyReportIncludeAI, forKey: .autoDailyReportIncludeAI)
        try container.encode(autoDailyReportAutoOpenWindow, forKey: .autoDailyReportAutoOpenWindow)
        try container.encodeIfPresent(lastAutoDailyReportRunDate, forKey: .lastAutoDailyReportRunDate)
    }

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
