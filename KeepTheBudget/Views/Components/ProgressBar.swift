//
//  ProgressBar.swift
//  KeepTheBudget
//
//  Progress bar component for displaying goal completion
//

import SwiftUI

struct ProgressBar: View {
    let percentage: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                    .cornerRadius(4)

                // Progress
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 8)
                    .cornerRadius(4)
                    .animation(.easeInOut(duration: 0.3), value: percentage)
            }
        }
        .frame(height: 8)
    }
}
