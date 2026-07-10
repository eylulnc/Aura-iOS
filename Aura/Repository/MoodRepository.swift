import Foundation
import SwiftData
import FirebaseFirestore
import WidgetKit

@MainActor
final class MoodRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Write (local + optional sync)

    func logMood(moodId: Int, note: String?, userId: String = "", syncUserId: String? = nil) throws {
        let today = MoodEntry.todayString()
        if let existing = try getByDate(today, userId: userId) {
            existing.mood = moodId
            existing.note = note?.isEmpty == true ? nil : note
            existing.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            try context.save()
            if let uid = syncUserId { Task { await syncToFirestore(existing, userId: uid) } }
        } else {
            let entry = MoodEntry(userId: userId, date: today, mood: moodId, note: note?.isEmpty == true ? nil : note)
            context.insert(entry)
            try context.save()
            if let uid = syncUserId { Task { await syncToFirestore(entry, userId: uid) } }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func editMood(_ entry: MoodEntry, moodId: Int, note: String?, syncUserId: String? = nil) throws {
        entry.mood = moodId
        entry.note = note?.isEmpty == true ? nil : note
        entry.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        try context.save()
        if let uid = syncUserId { Task { await syncToFirestore(entry, userId: uid) } }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteMood(_ entry: MoodEntry, syncUserId: String? = nil) throws {
        let id = entry.id
        context.delete(entry)
        try context.save()
        if let uid = syncUserId { Task { await deleteFromFirestore(entryId: id, userId: uid) } }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteAllLocal() throws {
        try context.delete(model: MoodEntry.self)
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteAll(syncUserId: String? = nil) throws {
        try deleteAllLocal()
        if let uid = syncUserId { Task { await deleteAllFromFirestore(userId: uid) } }
    }

    // MARK: - Read

    func getByDate(_ date: String, userId: String = "") throws -> MoodEntry? {
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.date == date && $0.userId == userId }
        )
        return try context.fetch(descriptor).first
    }

    func getAll(userId: String = "") throws -> [MoodEntry] {
        let descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.userId == userId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func getEarliestEntryDate(userId: String = "") throws -> String? {
        var descriptor = FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.userId == userId },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.date
    }

    // MARK: - Firestore sync

    func syncToFirestore(_ entry: MoodEntry, userId: String) async {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var data: [String: Any] = [
            "id": entry.id,
            "userId": userId,
            "date": entry.date,
            "timestamp": entry.timestamp,
            "mood": entry.mood,
            "syncedAt": now
        ]
        if let note = entry.note { data["note"] = note }
        try? await userEntries(userId).document(entry.id).setData(data)
        entry.syncedAt = now
        try? context.save()
    }

    func deleteFromFirestore(entryId: String, userId: String) async {
        try? await userEntries(userId).document(entryId).delete()
    }

    func deleteAllFromFirestore(userId: String) async {
        guard let docs = try? await userEntries(userId).getDocuments() else { return }
        for doc in docs.documents {
            try? await userEntries(userId).document(doc.documentID).delete()
        }
    }

    // MARK: - Sync state on login

    func checkSyncStateOnLogin(userId: String) async -> SyncState {
        let localGuest = (try? getAll(userId: "")) ?? []
        let hasLocal = !localGuest.isEmpty
        let snapshot = try? await userEntries(userId).limit(to: 1).getDocuments()
        let hasRemote = !(snapshot?.documents.isEmpty ?? true)
        switch (hasLocal, hasRemote) {
        case (true, false): return .uploadLocal
        case (false, true): return .downloadRemote
        case (true, true):  return .conflict
        default:            return .noData
        }
    }

    // Keep device data — migrate guest entries to Firebase UID and upload
    func pushLocalToRemote(userId: String) async {
        let guestEntries = (try? getAll(userId: "")) ?? []
        await deleteAllFromFirestore(userId: userId)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        for entry in guestEntries {
            entry.userId = userId
            entry.syncedAt = now
            await syncToFirestore(entry, userId: userId)
        }
        try? context.save()
    }

    // Keep account data — wipe local guest entries and download remote
    func pullRemoteToLocal(userId: String) async {
        try? deleteAllLocal()
        guard let docs = try? await userEntries(userId).getDocuments() else { return }
        for doc in docs.documents {
            let d = doc.data()
            guard
                let id       = d["id"]        as? String,
                let date     = d["date"]      as? String,
                let ts       = d["timestamp"] as? Int64,
                let mood     = d["mood"]      as? Int
            else { continue }
            let note     = d["note"]      as? String
            let syncedAt = d["syncedAt"]  as? Int64
            let entry = MoodEntry(id: id, userId: userId, date: date,
                                  timestamp: ts, mood: mood, note: note, syncedAt: syncedAt)
            context.insert(entry)
        }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Helpers

    private func userEntries(_ userId: String) -> CollectionReference {
        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("mood_entries")
    }
}
