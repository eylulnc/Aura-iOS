import SwiftUI

struct ContentView: View {
    @AppStorage("theme_mode") private var themeModeName: String = ThemeMode.system.rawValue

    @Environment(\.colorScheme) private var systemColorScheme

    private var themeMode: ThemeMode { ThemeMode(rawValue: themeModeName) ?? .system }

    private var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }

    private var auraColors: AuraColors {
        let isDark: Bool
        switch themeMode {
        case .light:  isDark = false
        case .dark:   isDark = true
        case .system: isDark = systemColorScheme == .dark
        }
        return isDark ? .dark : .light
    }

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environment(\.auraColors, auraColors)
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView()
}
