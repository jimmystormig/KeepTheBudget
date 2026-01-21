//
//  GoalStatus.swift
//  KeepTheBudget
//
//  Represents the status of time tracking relative to goals
//

import Foundation

enum GoalStatus {
    case normal      // Within goal
    case overGoal    // Exceeds goal (show RED warning)
}
