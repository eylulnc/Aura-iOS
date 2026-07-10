//
//  AuraApp.swift
//  Aura
//
//  Created by Eylul Naz Can on 11.04.2026.
//

import SwiftUI
import SwiftData
import FirebaseCore
import UserNotifications

@main
struct AuraApp: App {
    init() {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(AppGroup.sharedModelContainer)
    }
}
