import Foundation
import SwiftData

@MainActor
final class MoodRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Write

    func logMood(moodId: Int, note: String?, userId: String = "") throws {
        let today = MoodEntry.todayString()
        if let existing = try getByDate(today, userId: userId) {
            existing.mood = moodId
            existing.note = note?.isEmpty == true ? nil : note
            existing.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        } else {
            let entry = MoodEntry(
                userId: userId,
                date: today,
                mood: moodId,
                note: note?.isEmpty == true ? nil : note
            )
            context.insert(entry)
        }
        try context.save()
        // TODO: syncToFirestore (Phase 5)
    }

    func editMood(_ entry: MoodEntry, moodId: Int, note: String?) throws {
        entry.mood = moodId
        entry.note = note?.isEmpty == true ? nil : note
        entry.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        try context.save()
        // TODO: syncToFirestore (Phase 5)
    }

    func deleteMood(_ entry: MoodEntry) throws {
        context.delete(entry)
        try context.save()
        // TODO: delete from Firestore (Phase 5)
    }

    func deleteAllLocal() throws {
        try context.delete(model: MoodEntry.self)
        try context.save()
    }

    func deleteAll() throws {
        try deleteAllLocal()
        // TODO: delete from Firestore (Phase 5)
    }

    // MARK: - Read

    func getByDate(_ date: String, userId: String = "") throws -> MoodEntry? {
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { entry in
                entry.date == date && entry.userId == userId
            }
        )
        return try context.fetch(descriptor).first
    }

    func getAll(userId: String = "") throws -> [MoodEntry] {
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { entry in
                entry.userId == userId
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func getEarliestEntryDate(userId: String = "") throws -> String? {
        var descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { entry in
                entry.userId == userId
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.date
    }
}
