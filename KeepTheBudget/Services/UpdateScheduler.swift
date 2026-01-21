//
//  UpdateScheduler.swift
//  KeepTheBudget
//
//  Schedules periodic updates of calendar data
//

import Foundation

class UpdateScheduler {
    private var timer: Timer?
    private let intervalMinutes: Int
    private let updateHandler: () async -> Void

    init(intervalMinutes: Int, updateHandler: @escaping () async -> Void) {
        self.intervalMinutes = intervalMinutes
        self.updateHandler = updateHandler
    }

    func start() {
        stop() // Stop any existing timer

        let intervalSeconds = TimeInterval(intervalMinutes * 60)

        timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task {
                await self?.updateHandler()
            }
        }

        // Ensure timer runs in common run loop modes to work during scrolling, etc.
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        print("Update scheduler started with \(intervalMinutes) minute interval")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        print("Update scheduler stopped")
    }

    func triggerImmediateUpdate() {
        Task {
            await updateHandler()
        }
    }

    deinit {
        stop()
    }
}
