//
//  TimeReport.swift
//  KeepTheBudget
//
//  Data structures for hierarchical time report with grouping and rounding
//  Supports both weekly and daily report formats
//

import Foundation

/// Main time report containing hierarchical time groupings
struct TimeReport {
    let firstLevelGroups: [FirstLevelGroup]
    let startDate: Date
    let endDate: Date
    let totalMinutes: Int

    /// Format report as readable text for clipboard
    /// Automatically detects report type based on date range
    func toText() -> String {
        var output = ""

        // Header with date range
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let startStr = dateFormatter.string(from: startDate)

        // For end date, include year if different from start
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)

        if startYear == endYear {
            dateFormatter.dateFormat = "MMM d, yyyy"
        } else {
            dateFormatter.dateFormat = "MMM d, yyyy"
        }
        let endStr = dateFormatter.string(from: endDate)

        // Determine header based on date range
        let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if daysDifference >= 6 {
            // Weekly report
            output += "Week of \(startStr) - \(endStr)\n"
        } else {
            // Daily or custom range report
            output += "Report: \(startStr) - \(endStr)\n"
        }

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
