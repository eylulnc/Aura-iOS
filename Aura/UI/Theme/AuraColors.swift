import SwiftUI

struct AuraColors {
    let background: Color
    let surface: Color
    let surfaceSubtle: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let border: Color
    let isDark: Bool
}

extension AuraColors {
    static let light = AuraColors(
        background:    Color(hex: "#F9F8F5"),
        surface:       Color(hex: "#FFFFFF"),
        surfaceSubtle: Color(hex: "#F0EFEB"),
        textPrimary:   Color(hex: "#1A1917"),
        textSecondary: Color(hex: "#89857E"),
        accent:        Color(hex: "#7B96E8"),
        border:        Color(hex: "#E8E6E1"),
        isDark: false
    )

    static let dark = AuraColors(
        background:    Color(hex: "#111110"),
        surface:       Color(hex: "#1C1C1A"),
        surfaceSubtle: Color(hex: "#252523"),
        textPrimary:   Color(hex: "#EDECEA"),
        textSecondary: Color(hex: "#706C65"),
        accent:        Color(hex: "#A8BCF0"),
        border:        Color(hex: "#2E2E2C"),
        isDark: true
    )
}

// MARK: - Environment

private struct AuraColorsKey: EnvironmentKey {
    static let defaultValue: AuraColors = .light
}

extension EnvironmentValues {
    var auraColors: AuraColors {
        get { self[AuraColorsKey.self] }
        set { self[AuraColorsKey.self] = newValue }
    }
}

// MARK: - Theme modifier

extension View {
    func auraTheme(colorScheme: ColorScheme) -> some View {
        let colors: AuraColors = colorScheme == .dark ? .dark : .light
        return self.environment(\.auraColors, colors)
    }
}
