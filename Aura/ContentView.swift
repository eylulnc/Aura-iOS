import SwiftUI

struct ContentView: View {
    @AppStorage("theme_mode") private var themeModeName: String = ThemeMode.system.rawValue
    @AppStorage("onboarding_done") private var hasCompletedOnboarding: Bool = false

    @Environment(\.colorScheme) private var systemColorScheme

    @State private var authRepo = AuthRepository()

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
        Group {
            if hasCompletedOnboarding {
                TabView {
                    DashboardView()
                        .tabItem { Label("Dashboard", systemImage: "house.fill") }
                    HistoryView()
                        .tabItem { Label("History", systemImage: "calendar") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                }
            } else {
                OnboardingView()
            }
        }
        .environment(authRepo)
        .environment(\.auraColors, auraColors)
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView()
}
