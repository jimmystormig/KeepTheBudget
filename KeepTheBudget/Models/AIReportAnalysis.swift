//
//  AIReportAnalysis.swift
//  KeepTheBudget
//
//  Model for AI-generated report analysis results
//

import Foundation

struct AIReportAnalysis {
    let summary: String           // 1-2 sentence summary
    let highlights: [String]      // 3-5 key bullet points
    let generatedAt: Date
    let error: String?            // If analysis failed

    var isSuccess: Bool {
        error == nil
    }
}
