import SwiftUI

struct LogMoodSheet: View {
    let initialMoodId: Int?
    let initialNote: String
    let isEditing: Bool
    let onConfirm: (Int, String) -> Void
    let onDismiss: () -> Void

    @Environment(\.auraColors) private var colors
    @State private var sliderValue: Double
    @State private var note: String

    private let noteMaxLength = 150

    init(initialMoodId: Int?, initialNote: String, isEditing: Bool,
         onConfirm: @escaping (Int, String) -> Void, onDismiss: @escaping () -> Void) {
        self.initialMoodId = initialMoodId
        self.initialNote = initialNote
        self.isEditing = isEditing
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        let initialIndex = initialMoodId
            .flatMap { id in MOOD_SLIDER_ORDER.firstIndex(where: { $0.id == id }) }
            ?? 6
        _sliderValue = State(initialValue: Double(initialIndex))
        _note = State(initialValue: initialNote)
    }

    private var selectedMood: MoodFace { MOOD_SLIDER_ORDER[Int(sliderValue.rounded())] }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: Spacing.xl)

                MoodImage(face: selectedMood, size: Spacing.moodFaceLargeSize)

                Spacer().frame(height: Spacing.m)

                Text(selectedMood.label)
                    .font(.system(size: FontSize.xl, weight: .bold))
                    .foregroundStyle(selectedMood.color)

                Text(selectedMood.sub)
                    .font(.system(size: FontSize.s))
                    .foregroundStyle(colors.textSecondary)

                Spacer().frame(height: Spacing.xl)

                Slider(value: $sliderValue, in: 0...12, step: 1)
                    .tint(selectedMood.color)
                    .padding(.horizontal, Spacing.xs)

                Spacer().frame(height: Spacing.xl)

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    TextField("How are you feeling?", text: $note, axis: .vertical)
                        .lineLimit(4...6)
                        .padding(Spacing.m)
                        .background(colors.surfaceSubtle)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
                        .overlay(
                            RoundedRectangle(cornerRadius: Spacing.radiusCard)
                                .stroke(colors.border, lineWidth: Spacing.borderWidth)
                        )
                        .onChange(of: note) {
                            if note.count > noteMaxLength {
                                note = String(note.prefix(noteMaxLength))
                            }
                        }

                    Text("\(note.count) / \(noteMaxLength)")
                        .font(.system(size: FontSize.xs))
                        .foregroundStyle(note.count >= noteMaxLength ? Color.red : colors.textSecondary)
                }

                Spacer().frame(height: Spacing.l)

                Button {
                    onConfirm(selectedMood.id, note)
                } label: {
                    Text(isEditing ? "Update" : "Log Mood")
                        .font(.system(size: FontSize.m, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.m)
                        .background(colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusButton))
                }

                Spacer().frame(height: Spacing.xxl)
            }
            .padding(.horizontal, Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
