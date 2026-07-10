import Foundation
import SwiftData

enum AppGroup {
    static let id = "group.com.eylulnc.Aura"

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
            fatalError("App Group container unavailable — check the \(id) entitlement on both targets.")
        }
        return url
    }

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([MoodEntry.self])
        let storeURL = containerURL.appendingPathComponent("Aura.sqlite")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
}
