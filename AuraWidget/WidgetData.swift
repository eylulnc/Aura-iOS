import Foundation
import SwiftData

enum WidgetData {
    static func todayMood() -> MoodFace? {
        let context = ModelContext(AppGroup.sharedModelContainer)
        let today = MoodEntry.todayString()
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.date == today }
        )
        guard let entry = try? context.fetch(descriptor).first else { return nil }
        return getMoodFace(id: entry.mood)
    }

    static func streak() -> Int {
        let context = ModelContext(AppGroup.sharedModelContainer)
        let descriptor = FetchDescriptor<MoodEntry>()
        let dates = Set((try? context.fetch(descriptor).map(\.date)) ?? [])

        let today = MoodEntry.todayString()
        var cursor = Date()
        if !dates.contains(today) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while dates.contains(MoodEntry.dateFormatter.string(from: cursor)) {
            count += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    static var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}
