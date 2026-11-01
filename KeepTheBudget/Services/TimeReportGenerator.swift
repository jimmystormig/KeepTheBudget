//
//  TimeReportGenerator.swift
//  KeepTheBudget
//
//  Service for generating hierarchical time reports with grouping and time rounding
//  Supports both weekly and daily report formats
//

import Foundation

/// Generates time reports from calendar events with hierarchical grouping
class TimeReportGenerator {
    private let timeCalculator: TimeCalculator

    /// Groups with at most this many (unrounded) minutes are merged into "Blandat"
    private let blandatThresholdMinutes = 60
    private let blandatName = "Blandat"

    init(timeCalculator: TimeCalculator) {
        self.timeCalculator = timeCalculator
    }

    /// Generate hierarchical report from events with grouping and rounding
    func generateReport(from events: [CalendarEvent], startDate: Date, endDate: Date) -> TimeReport {
        // Step 1: Parse all events into parts
        let parsedEvents = events.compactMap { event -> ParsedEvent? in
            guard let parts = parseEventSubject(event.subject) else { return nil }
            return ParsedEvent(parts: parts, minutes: event.durationMinutes)
        }

        // Step 2: Group by first level
        var firstLevelDict: [String: [ParsedEvent]] = [:]
        for event in parsedEvents {
            firstLevelDict[event.parts.firstLevel, default: []].append(event)
        }

        // Step 3: Process each first-level group
        var firstLevelGroups: [FirstLevelGroup] = []

        for (firstLevelName, firstLevelEvents) in firstLevelDict {
            // Group by second level
            var secondLevelDict: [String: [ParsedEvent]] = [:]
            for event in firstLevelEvents {
                let secondLevelName = event.parts.secondLevel.isEmpty ? "(No category)" : event.parts.secondLevel
                secondLevelDict[secondLevelName, default: []].append(event)
            }

            // Step 4: Move small second-level groups to "Blandat" - format as "{SecondLevelName} - {third-level names}"
            let split = splitSmall(Array(secondLevelDict), minutes: { totalMinutes($0.value) }) { name, events in
                let thirdLevelNames = unique(events.map { $0.parts.thirdLevel }.filter { !$0.isEmpty })
                return thirdLevelNames.isEmpty ? name : "\(name) - \(thirdLevelNames.joined(separator: ", "))"
            }

            // Step 5: Build regular second-level groups (grouped and rounded on third level)
            var secondLevelGroupsList = split.kept.map { buildSecondLevelGroup(name: $0.key, events: $0.value) }

            if split.blandatMinutes > 0 {
                secondLevelGroupsList.append(SecondLevelGroup(
                    name: blandatName,
                    descriptions: split.blandatLines,
                    thirdLevelGroups: [],
                    roundedMinutes: roundUpToNearest30(split.blandatMinutes)
                ))
            }

            secondLevelGroupsList.sort(by: blandatLast(\.name, \.roundedMinutes))

            // Step 6: Calculate first-level total (sum of rounded second-level times)
            let firstLevelTotal = secondLevelGroupsList.reduce(0) { $0 + $1.roundedMinutes }

            firstLevelGroups.append(FirstLevelGroup(
                name: firstLevelName,
                secondLevelGroups: secondLevelGroupsList,
                totalMinutes: firstLevelTotal
            ))
        }

        // Sort first-level groups by time descending
        firstLevelGroups.sort { $0.totalMinutes > $1.totalMinutes }

        // Calculate grand total
        let grandTotal = firstLevelGroups.reduce(0) { $0 + $1.totalMinutes }

        return TimeReport(
            firstLevelGroups: firstLevelGroups,
            startDate: startDate,
            endDate: endDate,
            totalMinutes: grandTotal
        )
    }

    /// Group a second-level group's events by third level, merging small ones into "Blandat"
    /// Events without a third level count toward the second-level total without a row of their own
    private func buildSecondLevelGroup(name: String, events: [ParsedEvent]) -> SecondLevelGroup {
        var thirdLevelDict: [String: [ParsedEvent]] = [:]
        var minutesWithoutThirdLevel = 0

        for event in events {
            if event.parts.thirdLevel.isEmpty {
                minutesWithoutThirdLevel += event.minutes
            } else {
                thirdLevelDict[event.parts.thirdLevel, default: []].append(event)
            }
        }

        // Move small third-level groups to "Blandat" - format as "{ThirdLevelName} - {descriptions}"
        let split = splitSmall(Array(thirdLevelDict), minutes: { totalMinutes($0.value) }) { name, events in
            let descriptions = unique(events.flatMap { $0.parts.descriptions })
            return descriptions.isEmpty ? name : "\(name) - \(descriptions.joined(separator: ", "))"
        }

        // Round all times to nearest 30 minutes
        var thirdLevelGroups = split.kept.map { name, events in
            ThirdLevelGroup(
                name: name,
                descriptions: unique(events.flatMap { $0.parts.descriptions }),
                roundedMinutes: roundUpToNearest30(totalMinutes(events))
            )
        }

        if split.blandatMinutes > 0 {
            thirdLevelGroups.append(ThirdLevelGroup(
                name: blandatName,
                descriptions: split.blandatLines,
                roundedMinutes: roundUpToNearest30(split.blandatMinutes)
            ))
        }

        thirdLevelGroups.sort(by: blandatLast(\.name, \.roundedMinutes))

        let total = thirdLevelGroups.reduce(0) { $0 + $1.roundedMinutes }
            + roundUpToNearest30(minutesWithoutThirdLevel)

        return SecondLevelGroup(
            name: name,
            descriptions: [],
            thirdLevelGroups: thirdLevelGroups,
            roundedMinutes: total
        )
    }

    /// Split named groups into those kept as their own row and those (≤ threshold) merged into "Blandat"
    private func splitSmall(
        _ groups: [(key: String, value: [ParsedEvent])],
        minutes: ((key: String, value: [ParsedEvent])) -> Int,
        blandatLine: (String, [ParsedEvent]) -> String
    ) -> (kept: [(key: String, value: [ParsedEvent])], blandatLines: [String], blandatMinutes: Int) {
        var kept: [(key: String, value: [ParsedEvent])] = []
        var blandatLines: [String] = []
        var blandatMinutes = 0

        // Largest first so the Blandat lines read in a stable, meaningful order
        for group in groups.sorted(by: { minutes($0) > minutes($1) }) {
            let groupMinutes = minutes(group)
            if groupMinutes <= blandatThresholdMinutes {
                blandatMinutes += groupMinutes
                blandatLines.append(blandatLine(group.key, group.value))
            } else {
                kept.append(group)
            }
        }

        return (kept, blandatLines, blandatMinutes)
    }

    /// Sort by time descending, but put "Blandat" last
    private func blandatLast<T>(_ name: KeyPath<T, String>, _ minutes: KeyPath<T, Int>) -> (T, T) -> Bool {
        let blandatName = blandatName
        return { left, right in
            if left[keyPath: name] == blandatName { return false }
            if right[keyPath: name] == blandatName { return true }
            return left[keyPath: minutes] > right[keyPath: minutes]
        }
    }

    private func totalMinutes(_ events: [ParsedEvent]) -> Int {
        events.reduce(0) { $0 + $1.minutes }
    }

    /// Remove duplicates while keeping first-seen order
    private func unique(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            if !result.contains(value) { result.append(value) }
        }
    }

    /// Parse event subject into hierarchical parts
    /// Format: "FirstLevel - SecondLevel - ThirdLevel - Description1 - Description2"
    private func parseEventSubject(_ subject: String) -> EventParts? {
        let parts = subject.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }

        guard !parts.isEmpty else { return nil }

        let firstLevel = parts[0]
        let secondLevel = parts.count > 1 ? parts[1] : ""
        let thirdLevel = parts.count > 2 ? parts[2] : ""
        let descriptions = parts.count > 3 ? Array(parts[3...]) : []

        return EventParts(
            firstLevel: firstLevel,
            secondLevel: secondLevel,
            thirdLevel: thirdLevel,
            descriptions: descriptions
        )
    }

    /// Round minutes UP to nearest 30 minutes
    /// Examples: 1→30, 30→30, 31→60, 55→60, 61→90
    private func roundUpToNearest30(_ minutes: Int) -> Int {
        guard minutes > 0 else { return 0 }
        return ((minutes - 1) / 30 + 1) * 30
    }
}

/// Internal structure for parsed event subject
private struct EventParts {
    let firstLevel: String
    let secondLevel: String  // Empty string if no second part
    let thirdLevel: String  // Empty string if no third part
    let descriptions: [String]  // Fourth+ parts
}

/// Internal structure pairing parsed subject with event duration
private struct ParsedEvent {
    let parts: EventParts
    let minutes: Int
}
