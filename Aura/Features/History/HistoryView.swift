import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.auraColors) private var colors
    @Query(sort: \MoodEntry.date, order: .reverse) private var allEntries: [MoodEntry]

    @State private var vm = HistoryViewModel()

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("top")

                        MonthHeader(
                            month: vm.selectedMonth,
                            canGoPrev: vm.canGoPrev,
                            canGoNext: vm.canGoNext,
                            isCurrentMonth: vm.isCurrentMonth,
                            onPrev: { vm.prevMonth() },
                            onNext: { vm.nextMonth() },
                            onGoToToday: { vm.goToToday() }
                        )

                        Spacer().frame(height: Spacing.l)

                        CalendarGrid(
                            month: vm.selectedMonth,
                            entryByDay: vm.entryByDay,
                            selectedDay: vm.selectedDay,
                            onDayTap: { day in vm.selectDay(day) }
                        )

                        Spacer().frame(height: Spacing.l)

                        Rectangle()
                            .fill(colors.border)
                            .frame(height: Spacing.borderWidth)

                        Spacer().frame(height: Spacing.s)

                        SortRow(sortOrder: vm.sortOrder, onToggle: { vm.toggleSort() })

                        Spacer().frame(height: Spacing.s)

                        if vm.monthEntries.isEmpty {
                            HStack {
                                Spacer()
                                Text("No entries yet")
                                    .font(.system(size: FontSize.s))
                                    .foregroundStyle(colors.textSecondary)
                                Spacer()
                            }
                            .padding(.vertical, Spacing.xxl)
                        } else {
                            let todayStr = MoodEntry.todayString()
                            VStack(spacing: Spacing.s) {
                                ForEach(vm.monthEntries, id: \.id) { entry in
                                    EntryRow(
                                        entry: entry,
                                        onTap: { vm.openSheet(entry) },
                                        showEdit: entry.date == todayStr
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.l)
                }
                .background(colors.background)

                if !vm.monthEntries.isEmpty {
                    Button {
                        withAnimation { proxy.scrollTo("top", anchor: .top) }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: FontSize.m, weight: .semibold))
                            .foregroundStyle(colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(colors.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(colors.border, lineWidth: Spacing.borderWidth))
                    }
                    .padding(Spacing.l)
                }
            }
        }
        .onAppear { vm.context = context }
        .onChange(of: allEntries.map(\.timestamp), initial: true) { vm.update(entries: allEntries) }
        .sheet(isPresented: $vm.isSheetOpen, onDismiss: { vm.closeSheet() }) {
            if let entry = vm.sheetEntry {
                EntrySheetContent(
                    entry: entry,
                    onUpdate: { moodId, note in
                        vm.updateEntry(entry, moodId: moodId, note: note)
                        vm.closeSheet()
                    },
                    onDelete: {
                        vm.deleteEntry(entry)
                        vm.closeSheet()
                    },
                    onCancel: { vm.closeSheet() }
                )
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(colors.background)
            }
        }
    }
}

// MARK: - Month Header

private struct MonthHeader: View {
    let month: Date
    let canGoPrev: Bool
    let canGoNext: Bool
    let isCurrentMonth: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    let onGoToToday: () -> Void

    @Environment(\.auraColors) private var colors

    private var label: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    var body: some View {
        HStack {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.system(size: FontSize.l))
                    .foregroundStyle(canGoPrev ? colors.textPrimary : colors.border)
            }
            .disabled(!canGoPrev)

            Spacer()

            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: FontSize.l, weight: .semibold))
                    .foregroundStyle(colors.textPrimary)
                if !isCurrentMonth {
                    Button(action: onGoToToday) {
                        Text("Back to today")
                            .font(.system(size: FontSize.xs, weight: .medium))
                            .foregroundStyle(colors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: FontSize.l))
                    .foregroundStyle(canGoNext ? colors.textPrimary : colors.border)
            }
            .disabled(!canGoNext)
        }
    }
}

// MARK: - Sort Row

private struct SortRow: View {
    let sortOrder: SortOrder
    let onToggle: () -> Void

    @Environment(\.auraColors) private var colors

    var body: some View {
        HStack {
            Spacer()
            Button(action: onToggle) {
                Text(sortOrder == .newest ? "Newest first" : "Oldest first")
                    .font(.system(size: FontSize.xs))
                    .foregroundStyle(colors.textPrimary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusPill))
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.radiusPill)
                            .stroke(colors.border, lineWidth: Spacing.borderWidth)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Calendar Grid

private struct CalendarGrid: View {
    let month: Date
    let entryByDay: [Int: MoodEntry]
    let selectedDay: Int?
    let onDayTap: (Int) -> Void

    @Environment(\.auraColors) private var colors

    private static let weekdaySymbols: [String] = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let cal = Calendar.current
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let weekdayOfFirst = cal.component(.weekday, from: month) // 1=Sun..7=Sat
        // Convert to Monday=0..Sunday=6
        let firstOffset = (weekdayOfFirst + 5) % 7
        let totalCells = firstOffset + daysInMonth
        let rows = (totalCells + 6) / 7

        let today = Date()
        let isCurrentMonth = cal.isDate(month, equalTo: today, toGranularity: .month)
        let todayDay = cal.component(.day, from: today)

        VStack(spacing: Spacing.s) {
            HStack {
                ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.system(size: FontSize.xs, weight: .medium))
                        .foregroundStyle(colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = row * 7 + col - firstOffset + 1
                        if day >= 1 && day <= daysInMonth {
                            DayCell(
                                day: day,
                                entry: entryByDay[day],
                                isToday: isCurrentMonth && day == todayDay,
                                isSelected: selectedDay == day,
                                onTap: { if entryByDay[day] != nil { onDayTap(day) } }
                            )
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Int
    let entry: MoodEntry?
    let isToday: Bool
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.auraColors) private var colors

    var body: some View {
        let face = entry.map { getMoodFace(id: $0.mood) }
        let moodColor = face?.color
        let borderColor: Color = {
            if isSelected { return colors.accent }
            if isToday { return moodColor ?? colors.accent }
            return colors.border
        }()
        let lineWidth: CGFloat = (isToday || isSelected)
            ? Spacing.selectionBorderWidth
            : Spacing.borderWidth

        Button(action: onTap) {
            ZStack {
                if let face, let moodColor {
                    Circle()
                        .fill(moodColor.opacity(0.18))
                        .overlay(Circle().stroke(borderColor, lineWidth: lineWidth))
                    Image(face.imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .overlay(Circle().stroke(borderColor, lineWidth: lineWidth))
                    Text("\(day)")
                        .font(.system(size: FontSize.xs,
                                      weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? colors.accent : colors.textSecondary)
                }
            }
            .padding(3)
        }
        .buttonStyle(.plain)
        .disabled(entry == nil)
    }
}

// MARK: - Entry Row

private struct EntryRow: View {
    let entry: MoodEntry
    let onTap: () -> Void
    let showEdit: Bool

    @Environment(\.auraColors) private var colors

    private var dateLabel: String {
        guard let d = MoodEntry.dateFormatter.date(from: entry.date) else { return entry.date }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: d)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.m) {
                let face = getMoodFace(id: entry.mood)
                MoodImage(face: face, size: Spacing.moodFaceSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(face.label)
                        .font(.system(size: FontSize.m, weight: .semibold))
                        .foregroundStyle(face.color)
                    Text(dateLabel)
                        .font(.system(size: FontSize.xs))
                        .foregroundStyle(colors.textSecondary)
                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: FontSize.s))
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showEdit {
                    Image(systemName: "pencil")
                        .font(.system(size: FontSize.l))
                        .foregroundStyle(colors.accent)
                }
            }
            .padding(Spacing.m)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Entry Sheet (view for past, edit for today)

private struct EntrySheetContent: View {
    let entry: MoodEntry
    let onUpdate: (Int, String) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @Environment(\.auraColors) private var colors

    var body: some View {
        let isToday = entry.date == MoodEntry.todayString()
        if isToday {
            LogMoodSheet(
                initialMoodId: entry.mood,
                initialNote: entry.note ?? "",
                isEditing: true,
                onConfirm: onUpdate,
                onDismiss: onCancel
            )
        } else {
            EntryViewSheet(entry: entry)
        }
    }
}

private struct EntryViewSheet: View {
    let entry: MoodEntry

    @Environment(\.auraColors) private var colors

    private var dateLabel: String {
        guard let d = MoodEntry.dateFormatter.date(from: entry.date) else { return entry.date }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: d)
    }

    var body: some View {
        let face = getMoodFace(id: entry.mood)

        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: Spacing.xl)

                MoodImage(face: face, size: Spacing.moodFaceLargeSize)

                Spacer().frame(height: Spacing.m)

                Text(face.label)
                    .font(.system(size: FontSize.l, weight: .semibold))
                    .foregroundStyle(face.color)

                Spacer().frame(height: Spacing.s)

                Text(dateLabel)
                    .font(.system(size: FontSize.s))
                    .foregroundStyle(colors.textSecondary)

                if let note = entry.note, !note.isEmpty {
                    Spacer().frame(height: Spacing.l)
                    Text(note)
                        .font(.system(size: FontSize.s))
                        .foregroundStyle(colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                }

                Spacer().frame(height: Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
}
