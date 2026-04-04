//
//  AIReportAnalysis.swift
//  KeepTheBudget
//
//  Model for AI-generated report analysis results
//

import Foundation

struct AIReportAnalysis {
    let yesterdayWork: [String]      // What I did yesterday (from calendar + email + Teams)
    let todayWork: [String]          // What I should do today (from upcoming events + unread mail/Teams)
    let correlations: [Correlation]  // Phase 3: Cross-references between events/emails/chats
    let priorities: [Priority]       // Phase 3: AI-identified priority items
    let generatedAt: Date
    let error: String?               // If analysis failed

    var isSuccess: Bool {
        error == nil
    }
}

/// Correlation between different communication types (Phase 3)
struct Correlation: Identifiable {
    let id: UUID
    let type: CorrelationType
    let title: String
    let description: String
    let items: [String]  // References to specific events, emails, or chats

    init(type: CorrelationType, title: String, description: String, items: [String]) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.items = items
    }
}

/// Types of correlations that AI can identify
enum CorrelationType: String {
    case eventToEmail = "Meeting → Email"
    case eventToChat = "Meeting → Chat"
    case emailToChat = "Email → Chat"
    case multiChannel = "Multi-channel"  // Same topic across all three

    var icon: String {
        switch self {
        case .eventToEmail: return "arrow.right"
        case .eventToChat: return "arrow.right"
        case .emailToChat: return "arrow.right"
        case .multiChannel: return "arrow.triangle.branch"
        }
    }
}

/// Priority item identified by AI (Phase 3)
struct Priority: Identifiable {
    let id: UUID
    let level: PriorityLevel
    let title: String
    let reason: String
    let relatedItems: [String]

    init(level: PriorityLevel, title: String, reason: String, relatedItems: [String]) {
        self.id = UUID()
        self.level = level
        self.title = title
        self.reason = reason
        self.relatedItems = relatedItems
    }
}

/// Priority levels
enum PriorityLevel: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "yellow"
        }
    }

    var icon: String {
        switch self {
        case .high: return "exclamationmark.3"
        case .medium: return "exclamationmark.2"
        case .low: return "exclamationmark"
        }
    }
}
