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

// MARK: - Report Text Styling

extension Color {
    /// Secondary text for report windows. `.secondary` is too faint on glass surfaces.
    static let reportSecondary = Color.primary.opacity(0.78)
}

private struct ReportTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var reportTextScale: CGFloat {
        get { self[ReportTextScaleKey.self] }
        set { self[ReportTextScaleKey.self] = newValue }
    }
}

/// Applies a macOS text style scaled by the report zoom level.
private struct ReportFontModifier: ViewModifier {
    let style: Font.TextStyle
    @Environment(\.reportTextScale) private var scale

    func body(content: Content) -> some View {
        content.font(.system(size: Self.baseSize(for: style) * scale,
                             weight: style == .headline ? .bold : .regular))
    }

    /// Default macOS point sizes for each text style.
    private static func baseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 26
        case .title: return 22
        case .title2: return 17
        case .title3: return 15
        case .headline, .body: return 13
        case .callout: return 12
        case .subheadline: return 11
        case .footnote, .caption, .caption2: return 10
        @unknown default: return 13
        }
    }
}

/// Persists the report zoom level and handles ⌘+ / ⌘- / ⌘0.
private struct ReportZoomModifier: ViewModifier {
    static let range: ClosedRange<Double> = 0.8...2.5
    static let step = 0.1

    @AppStorage("reportTextScale") private var scale = 1.0

    func body(content: Content) -> some View {
        content
            .reportFont(.body)
            .environment(\.reportTextScale, CGFloat(scale))
            .background {
                // Invisible buttons carry the shortcuts; the app has no main menu (LSUIElement).
                // Both "+" and "=" are bound so ⌘+ works on Swedish and US layouts alike.
                Group {
                    Button("Zoom In") { zoom(by: Self.step) }
                        .keyboardShortcut("+", modifiers: .command)
                    Button("Zoom In") { zoom(by: Self.step) }
                        .keyboardShortcut("=", modifiers: .command)
                    Button("Zoom Out") { zoom(by: -Self.step) }
                        .keyboardShortcut("-", modifiers: .command)
                    Button("Actual Size") { scale = 1.0 }
                        .keyboardShortcut("0", modifiers: .command)
                }
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
    }

    private func zoom(by delta: Double) {
        let newScale = ((scale + delta) * 10).rounded() / 10
        scale = min(max(newScale, Self.range.lowerBound), Self.range.upperBound)
    }
}

extension View {
    func reportFont(_ style: Font.TextStyle) -> some View {
        modifier(ReportFontModifier(style: style))
    }

    /// Enables ⌘+ / ⌘- / ⌘0 text zoom for a report window's content.
    func reportZoomable() -> some View {
        modifier(ReportZoomModifier())
    }
}
