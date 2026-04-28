import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.auraColors) private var colors
    @Query(sort: \MoodEntry.date, order: .reverse) private var allEntries: [MoodEntry]

    @State private var vm = DashboardViewModel()
    @State private var showSheet = false

    var body: some View {
        Group {
            if vm.isLoading {
                Color(colors.background).ignoresSafeArea()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        Text(greeting())
                            .font(.system(size: FontSize.xl, weight: .semibold))
                            .foregroundStyle(colors.textPrimary)

                        Text(formattedDate())
                            .font(.system(size: FontSize.s))
                            .foregroundStyle(colors.textSecondary)
                            .padding(.top, 2)

                        Spacer().frame(height: Spacing.l)

                        // Today card
                        TodayCard(entry: vm.todayEntry, onTap: { showSheet = true })

                        Spacer().frame(height: Spacing.l)

                        // Stat row 1: streak + days logged
                        HStack(spacing: Spacing.m) {
                            TextStatCard(
                                label: "Streak",
                                value: "\(vm.streak)",
                                unit: vm.streak == 1 ? "day" : "days",
                                valueColor: vm.streak > 0 ? colors.accent : colors.textPrimary,
                                backgroundColor: vm.streak > 0 ? colors.accent.opacity(0.08) : colors.surface
                            )
                            TextStatCard(
                                label: "This Month",
                                value: vm.daysThisMonth > 0 ? "\(vm.daysThisMonth)" : "—",
                                unit: vm.daysThisMonth > 0 ? "days logged" : nil,
                                valueColor: colors.textPrimary,
                                backgroundColor: colors.surface
                            )
                        }
                        .fixedSize(horizontal: false, vertical: true)

                        Spacer().frame(height: Spacing.m)

                        // Stat row 2: top mood + positive %
                        HStack(spacing: Spacing.m) {
                            if let topFace = vm.topMoodsThisMonth.first?.0 {
                                MoodStatCard(label: "Top Mood", face: topFace)
                            } else {
                                TextStatCard(
                                    label: "Top Mood",
                                    value: "—",
                                    unit: nil,
                                    valueColor: colors.textSecondary,
                                    backgroundColor: colors.surface
                                )
                            }
                            TextStatCard(
                                label: "Weekly Positive",
                                value: vm.positivePercent.map { "\($0)%" } ?? "—",
                                unit: vm.positivePercent != nil ? "of days" : nil,
                                valueColor: vm.positivePercent != nil ? colors.accent : colors.textSecondary,
                                backgroundColor: colors.surface,
                                infoText: "Percentage of positive moods over the last 7 days. Shown after at least 3 days are logged."
                            )
                        }
                        .fixedSize(horizontal: false, vertical: true)

                        Spacer().frame(height: Spacing.l)

                        MoodTrendCard(weekEntries: vm.weekEntries)

                        if !vm.topMoodsThisMonth.isEmpty {
                            Spacer().frame(height: Spacing.l)
                            TopMoodsCard(topMoods: vm.topMoodsThisMonth)
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)
                    .padding(.bottom, Spacing.xl)
                }
                .background(colors.background)
            }
        }
        .onAppear { vm.context = context }
        .onChange(of: allEntries.map(\.timestamp), initial: true) { vm.update(entries: allEntries) }
        .sheet(isPresented: $showSheet) {
            LogMoodSheet(
                initialMoodId: vm.todayEntry?.mood,
                initialNote: vm.todayEntry?.note ?? "",
                isEditing: vm.todayEntry != nil,
                onConfirm: { moodId, note in
                    vm.confirmMood(moodId: moodId, note: note)
                    showSheet = false
                },
                onDismiss: { showSheet = false }
            )
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(colors.background)
        }
    }
}

// MARK: - Today Card

private struct TodayCard: View {
    let entry: MoodEntry?
    let onTap: () -> Void

    @Environment(\.auraColors) private var colors

    var body: some View {
        Button(action: onTap) {
            HStack {
                if let entry {
                    let face = getMoodFace(id: entry.mood)
                    MoodImage(face: face, size: Spacing.moodFaceMediumSize)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(face.label)
                            .font(.system(size: FontSize.m, weight: .semibold))
                            .foregroundStyle(face.color)
                        Text(face.sub)
                            .font(.system(size: FontSize.s))
                            .foregroundStyle(colors.textSecondary)
                        if let note = entry.note, !note.isEmpty {
                            Text(note)
                                .font(.system(size: FontSize.xs))
                                .foregroundStyle(colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, Spacing.m)

                    Image(systemName: "pencil")
                        .foregroundStyle(colors.accent)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("How are you feeling?")
                            .font(.system(size: FontSize.m, weight: .medium))
                            .foregroundStyle(colors.textPrimary)
                        Text("Tap to log today's mood")
                            .font(.system(size: FontSize.s))
                            .foregroundStyle(colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "plus")
                        .foregroundStyle(colors.accent)
                }
            }
            .padding(Spacing.l)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private func greeting() -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    if hour < 12 { return "Good morning" }
    if hour < 17 { return "Good afternoon" }
    return "Good evening"
}

private func formattedDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE, MMMM d"
    return formatter.string(from: Date())
}

#Preview {
    DashboardView()
        .modelContainer(for: MoodEntry.self, inMemory: true)
}
