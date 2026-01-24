//
//  WeeklyReportGenerator.swift
//  KeepTheBudget
//
//  Service for generating hierarchical weekly reports with grouping and time rounding
//

import Foundation

/// Generates weekly reports from calendar events with hierarchical grouping
class WeeklyReportGenerator {
    private let timeCalculator: TimeCalculator

    init(timeCalculator: TimeCalculator) {
        self.timeCalculator = timeCalculator
    }

    /// Generate hierarchical report from events with grouping and rounding
    func generateReport(from events: [CalendarEvent], startDate: Date, endDate: Date) -> WeeklyReport {
        // Step 1: Parse all events into parts
        let parsedEvents = events.compactMap { event -> (EventParts, Int)? in
            guard let parts = parseEventSubject(event.subject) else { return nil }
            let minutes = event.durationMinutes
            return (parts, minutes)
        }

        // Step 2: Group by first level
        var firstLevelDict: [String: [(EventParts, Int)]] = [:]
        for (parts, minutes) in parsedEvents {
            firstLevelDict[parts.firstLevel, default: []].append((parts, minutes))
        }

        // Step 3: Process each first-level group
        var firstLevelGroups: [FirstLevelGroup] = []

        for (firstLevelName, firstLevelEvents) in firstLevelDict {
            // Group by second level
            var secondLevelDict: [String: [(descriptions: [String], minutes: Int)]] = [:]

            for (parts, minutes) in firstLevelEvents {
                let secondLevelName = parts.secondLevel.isEmpty ? "(No category)" : parts.secondLevel
                secondLevelDict[secondLevelName, default: []].append((parts.descriptions, minutes))
            }

            // Step 4: Calculate original totals for each second-level group
            var secondLevelTotals: [(name: String, originalMinutes: Int, descriptions: [String])] = []

            for (secondLevelName, items) in secondLevelDict {
                let totalMinutes = items.reduce(0) { $0 + $1.minutes }
                let allDescriptions = items.flatMap { $0.descriptions }
                secondLevelTotals.append((secondLevelName, totalMinutes, allDescriptions))
            }

            // Step 5: Move small groups (≤60 min) to "Blandat"
            var regularGroups: [(name: String, minutes: Int, descriptions: [String])] = []
            var blandatDescriptions: [String] = []
            var blandatMinutes = 0

            for (name, originalMinutes, descriptions) in secondLevelTotals {
                if originalMinutes <= 60 {
                    // Move to Blandat - format as "{SecondLevelName} - {descriptions}"
                    blandatMinutes += originalMinutes

                    let formattedDescription: String
                    if descriptions.isEmpty {
                        formattedDescription = name
                    } else {
                        formattedDescription = "\(name) - \(descriptions.joined(separator: ", "))"
                    }
                    blandatDescriptions.append(formattedDescription)
                } else {
                    regularGroups.append((name, originalMinutes, descriptions))
                }
            }

            // Step 6: Round all times to nearest 30 minutes
            var secondLevelGroupsList: [SecondLevelGroup] = []

            for (name, minutes, descriptions) in regularGroups {
                let rounded = roundUpToNearest30(minutes)
                secondLevelGroupsList.append(SecondLevelGroup(
                    name: name,
                    descriptions: descriptions,
                    roundedMinutes: rounded
                ))
            }

            // Add Blandat group if it has content
            if blandatMinutes > 0 {
                let rounded = roundUpToNearest30(blandatMinutes)
                secondLevelGroupsList.append(SecondLevelGroup(
                    name: "Blandat",
                    descriptions: blandatDescriptions,
                    roundedMinutes: rounded
                ))
            }

            // Sort second-level groups by time descending, but put Blandat last
            secondLevelGroupsList.sort { left, right in
                if left.name == "Blandat" { return false }
                if right.name == "Blandat" { return true }
                return left.roundedMinutes > right.roundedMinutes
            }

            // Step 7: Calculate first-level total (sum of rounded second-level times)
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

        return WeeklyReport(
            firstLevelGroups: firstLevelGroups,
            weekStart: startDate,
            weekEnd: endDate,
            totalMinutes: grandTotal
        )
    }

    /// Parse event subject into hierarchical parts
    /// Format: "FirstLevel - SecondLevel - Description1 - Description2"
    private func parseEventSubject(_ subject: String) -> EventParts? {
        let parts = subject.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }

        guard !parts.isEmpty else { return nil }

        let firstLevel = parts[0]
        let secondLevel = parts.count > 1 ? parts[1] : ""
        let descriptions = parts.count > 2 ? Array(parts[2...]) : []

        return EventParts(
            firstLevel: firstLevel,
            secondLevel: secondLevel,
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
    let descriptions: [String]  // Third+ parts
}
