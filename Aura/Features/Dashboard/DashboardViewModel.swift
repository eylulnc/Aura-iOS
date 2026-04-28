import SwiftUI
import SwiftData

@Observable
final class DashboardViewModel {
    private(set) var todayEntry: MoodEntry?
    private(set) var streak: Int = 0
    private(set) var weekEntries: [MoodEntry?] = Array(repeating: nil, count: 7)
    private(set) var topMoodsThisMonth: [(MoodFace, Int)] = []
    private(set) var daysThisMonth: Int = 0
    private(set) var positivePercent: Int? = nil
    private(set) var isLoading: Bool = true

    var context: ModelContext?

    func update(entries: [MoodEntry]) {
        let today = MoodEntry.todayString()
        todayEntry = entries.first { $0.date == today }
        weekEntries = computeWeekEntries(entries)
        streak = computeStreak(entries)
        topMoodsThisMonth = computeTopMoodsThisMonth(entries)
        daysThisMonth = countDaysThisMonth(entries)
        positivePercent = computePositivePercent(weekEntries)
        isLoading = false
    }

    func confirmMood(moodId: Int, note: String) {
        guard let context else { return }
        let repo = MoodRepository(context: context)
        try? repo.logMood(moodId: moodId, note: note.isEmpty ? nil : note)
        // TODO: refresh widgets (Phase 9)
    }

    // MARK: - Computations

    private func computeStreak(_ entries: [MoodEntry]) -> Int {
        let dateSet = Set(entries.map { $0.date })
        let today = MoodEntry.todayString()
        var date = Date()
        if !dateSet.contains(today) {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        var count = 0
        while dateSet.contains(MoodEntry.dateFormatter.string(from: date)) {
            count += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }

    private func computeWeekEntries(_ entries: [MoodEntry]) -> [MoodEntry?] {
        let entryMap = Dictionary(entries.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        let today = Date()
        return (0..<7).map { i in
            let daysAgo = 6 - i
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            return entryMap[MoodEntry.dateFormatter.string(from: date)]
        }
    }

    private func computeTopMoodsThisMonth(_ entries: [MoodEntry]) -> [(MoodFace, Int)] {
        let monthPrefix = String(MoodEntry.todayString().prefix(7))
        return entries
            .filter { $0.date.hasPrefix(monthPrefix) }
            .reduce(into: [Int: Int]()) { $0[$1.mood, default: 0] += 1 }
            .map { (getMoodFace(id: $0.key), $0.value) }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0 }
    }

    private func countDaysThisMonth(_ entries: [MoodEntry]) -> Int {
        let monthPrefix = String(MoodEntry.todayString().prefix(7))
        return entries.filter { $0.date.hasPrefix(monthPrefix) }.count
    }

    private func computePositivePercent(_ weekEntries: [MoodEntry?]) -> Int? {
        let existing = weekEntries.compactMap { $0 }
        guard existing.count >= 3 else { return nil }
        return existing.filter { POSITIVE_MOOD_IDS.contains($0.mood) }.count * 100 / existing.count
    }
}
