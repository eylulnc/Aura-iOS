import Foundation
import SwiftData

@Model
final class MoodEntry {
    @Attribute(.unique) var id: String
    var userId: String       // "" for guest
    var date: String         // "YYYY-MM-DD"
    var timestamp: Int64
    var mood: Int            // 1–13, matches MoodFace.id
    var note: String?
    var syncedAt: Int64?

    init(id: String = UUID().uuidString,
         userId: String = "",
         date: String,
         timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
         mood: Int,
         note: String? = nil,
         syncedAt: Int64? = nil) {
        self.id = id
        self.userId = userId
        self.date = date
        self.timestamp = timestamp
        self.mood = mood
        self.note = note
        self.syncedAt = syncedAt
    }
}

extension MoodEntry {
    static var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func todayString() -> String {
        dateFormatter.string(from: Date())
    }
}
