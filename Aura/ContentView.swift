//
//  ContentView.swift
//  Aura
//
//  Created by Eylul Naz Can on 11.04.2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("theme_mode") private var themeModeName: String = ThemeMode.system.rawValue

    private var preferredColorScheme: ColorScheme? {
        switch ThemeMode(rawValue: themeModeName) ?? .system {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
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
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView()
}
