//
//  GoldenGateUI.swift
//  KeepTheBudget
//
//  Shared visual treatment for the macOS 27 interface.
//

import SwiftUI

extension View {
    /// Applies Liquid Glass only to discrete, interactive content groups.
    /// System windows, popovers, and standard controls retain their native treatment.
    func goldenGateSurface(cornerRadius: CGFloat = 16) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
