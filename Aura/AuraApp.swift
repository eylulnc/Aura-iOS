//
//  AuraApp.swift
//  Aura
//
//  Created by Eylul Naz Can on 11.04.2026.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct AuraApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: MoodEntry.self)
    }
}
