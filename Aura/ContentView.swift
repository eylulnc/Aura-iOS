import SwiftUI

struct ContentView: View {
    @AppStorage("theme_mode") private var themeModeName: String = ThemeMode.system.rawValue
    @AppStorage("onboarding_done") private var hasCompletedOnboarding: Bool = false

    @Environment(\.colorScheme) private var systemColorScheme

    @State private var authRepo = AuthRepository()
    @State private var selectedTab = 0

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
                TabView(selection: $selectedTab) {
                    DashboardView()
                        .tabItem { Label("Dashboard", systemImage: "house.fill") }
                        .tag(0)
                    HistoryView()
                        .tabItem { Label("History", systemImage: "calendar") }
                        .tag(1)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                        .tag(2)
                }
            } else {
                OnboardingView()
            }
        }
        .environment(authRepo)
        .environment(\.auraColors, auraColors)
        .preferredColorScheme(preferredColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .openDashboardTab)) { _ in
            selectedTab = 0
        }
    }
}

#Preview {
    ContentView()
}
