//
//  CategorySummary.swift
//  KeepTheBudget
//
//  Represents time totals for a specific category
//

import Foundation

/// Represents time totals for a specific category
struct CategorySummary: Identifiable {
    let id = UUID()
    let category: String
    let dailyMinutes: Int
    let weeklyMinutes: Int
}
