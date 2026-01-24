//
//  WeeklyReport.swift
//  KeepTheBudget
//
//  Data structures for hierarchical weekly time report with grouping and rounding
//

import Foundation

/// Main weekly report containing hierarchical time groupings
struct WeeklyReport {
    let firstLevelGroups: [FirstLevelGroup]
    let weekStart: Date
    let weekEnd: Date
    let totalMinutes: Int

    /// Format report as readable text for clipboard
    func toText() -> String {
        var output = ""

        // Header with date range
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let startStr = dateFormatter.string(from: weekStart)

        // For end date, include year if different from start
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: weekStart)
        let endYear = calendar.component(.year, from: weekEnd)

        if startYear == endYear {
            dateFormatter.dateFormat = "MMM d, yyyy"
        } else {
            dateFormatter.dateFormat = "MMM d, yyyy"
        }
        let endStr = dateFormatter.string(from: weekEnd)

        output += "Week of \(startStr) - \(endStr)\n"
        output += "Total: \(TimeFormatter.format(minutes: totalMinutes))\n\n"

        // First-level groups
        for firstLevel in firstLevelGroups {
            output += "\(firstLevel.name) (\(TimeFormatter.format(minutes: firstLevel.totalMinutes)))\n"

            // Second-level groups
            for secondLevel in firstLevel.secondLevelGroups {
                output += "  - \(secondLevel.name) (\(TimeFormatter.format(minutes: secondLevel.roundedMinutes)))\n"

                // Descriptions as bullet points
                if !secondLevel.descriptions.isEmpty {
                    let combinedDescriptions = secondLevel.descriptions.joined(separator: ", ")
                    output += "    • \(combinedDescriptions)\n"
                }
            }

            output += "\n"
        }

        return output
    }
}

/// First-level grouping (e.g., "ProjectX")
struct FirstLevelGroup: Identifiable {
    let id = UUID()
    let name: String
    let secondLevelGroups: [SecondLevelGroup]
    let totalMinutes: Int  // Sum of rounded second-level times
}

/// Second-level grouping (e.g., "Development" or "Blandat")
struct SecondLevelGroup: Identifiable {
    let id = UUID()
    let name: String
    let descriptions: [String]  // Third+ parts from event subjects
    let roundedMinutes: Int  // Already rounded to nearest 30 minutes
}
