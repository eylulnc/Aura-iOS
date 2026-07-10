import SwiftUI
import SwiftData

enum SortOrder { case newest, oldest }

@Observable
final class HistoryViewModel {
    private(set) var allEntries: [MoodEntry] = []
    var selectedMonth: Date
    var selectedDay: Int? = nil
    var sortOrder: SortOrder = .newest

    var sheetEntry: MoodEntry? = nil
    var isSheetOpen: Bool = false

    var context: ModelContext?

    init() {
        self.selectedMonth = HistoryViewModel.firstOfMonth(Date())
    }

    func update(entries: [MoodEntry]) {
        self.allEntries = entries
    }

    // MARK: - Derived

    var firstEntryMonth: Date {
        let earliest = allEntries.map(\.date).min()
        guard let s = earliest, let d = MoodEntry.dateFormatter.date(from: s) else {
            return Self.firstOfMonth(Date())
        }
        return Self.firstOfMonth(d)
    }

    var monthEntries: [MoodEntry] {
        let prefix = Self.monthPrefix(selectedMonth)
        let inMonth = allEntries.filter { $0.date.hasPrefix(prefix) }
        let sorted = sortOrder == .newest
            ? inMonth.sorted { $0.timestamp > $1.timestamp }
            : inMonth.sorted { $0.timestamp < $1.timestamp }
        if let day = selectedDay {
            return sorted.filter { Int($0.date.suffix(2)) == day }
        }
        return sorted
    }

    var entryByDay: [Int: MoodEntry] {
        let prefix = Self.monthPrefix(selectedMonth)
        var result: [Int: MoodEntry] = [:]
        for e in allEntries where e.date.hasPrefix(prefix) {
            if let d = Int(e.date.suffix(2)) { result[d] = e }
        }
        return result
    }

    var canGoPrev: Bool { selectedMonth > firstEntryMonth }
    var canGoNext: Bool { selectedMonth < Self.firstOfMonth(Date()) }
    var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Actions

    func prevMonth() {
        guard canGoPrev else { return }
        if let d = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = Self.firstOfMonth(d)
            selectedDay = nil
        }
    }

    func nextMonth() {
        guard canGoNext else { return }
        if let d = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = Self.firstOfMonth(d)
            selectedDay = nil
        }
    }

    func selectDay(_ day: Int) {
        selectedDay = (selectedDay == day) ? nil : day
    }

    func goToToday() {
        selectedMonth = Self.firstOfMonth(Date())
        selectedDay = nil
    }

    func toggleSort() {
        sortOrder = sortOrder == .newest ? .oldest : .newest
    }

    func openSheet(_ entry: MoodEntry) {
        sheetEntry = entry
        isSheetOpen = true
    }

    func closeSheet() {
        isSheetOpen = false
        sheetEntry = nil
    }

    func updateEntry(_ entry: MoodEntry, moodId: Int, note: String) {
        guard let context else { return }
        let repo = MoodRepository(context: context)
        try? repo.editMood(entry, moodId: moodId, note: note.isEmpty ? nil : note)
    }

    func deleteEntry(_ entry: MoodEntry) {
        guard let context else { return }
        let repo = MoodRepository(context: context)
        try? repo.deleteMood(entry)
        if entry.date == MoodEntry.todayString(), AppPreferences.shared.notificationsEnabled {
            let hour = AppPreferences.shared.reminderHour
            let minute = AppPreferences.shared.reminderMinute
            Task { await NotificationService.shared.rescheduleToday(hour: hour, minute: minute) }
        }
    }

    // MARK: - Helpers

    static func firstOfMonth(_ date: Date) -> Date {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: comps) ?? date
    }

    static func monthPrefix(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }
}
