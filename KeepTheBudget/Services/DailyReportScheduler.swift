//
//  DailyReportScheduler.swift
//  KeepTheBudget
//
//  Schedules automatic daily meeting report generation at a configured time
//

import Foundation

class DailyReportScheduler {
    private var timer: Timer?
    private let storageManager: StorageManager
    private let onTrigger: () async -> Void
    private var preferences: AppPreferences

    init(storageManager: StorageManager, onTrigger: @escaping () async -> Void) {
        self.storageManager = storageManager
        self.onTrigger = onTrigger
        self.preferences = storageManager.loadPreferences()
    }

    func start() {
        stop()
        reloadPreferences()

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluateSchedule()
        }

        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        evaluateSchedule()
        print("Daily report scheduler started (\(preferences.autoDailyReportHour):\(String(format: "%02d", preferences.autoDailyReportMinute)))")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        print("Daily report scheduler stopped")
    }

    func reloadPreferences() {
        preferences = storageManager.loadPreferences()
    }

    private func evaluateSchedule() {
        reloadPreferences()

        guard preferences.autoDailyReportEnabled else { return }

        let now = Date()
        let calendar = Calendar.current

        if preferences.autoDailyReportWeekdaysOnly && !WorkdayCalculator.isWorkday(now) {
            return
        }

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        guard hour == clampedHour, minute == clampedMinute else {
            return
        }

        if let lastRun = preferences.lastAutoDailyReportRunDate,
           calendar.isDate(lastRun, inSameDayAs: now) {
            return
        }

        Task {
            await onTrigger()
        }
    }

    private var clampedHour: Int {
        max(0, min(23, preferences.autoDailyReportHour))
    }

    private var clampedMinute: Int {
        max(0, min(59, preferences.autoDailyReportMinute))
    }

    deinit {
        stop()
    }
}
