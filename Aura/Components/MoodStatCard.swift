import SwiftUI

struct MoodStatCard: View {
    let label: String
    let face: MoodFace

    @Environment(\.auraColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.system(size: FontSize.s))
                .foregroundStyle(colors.textSecondary)

            Spacer().frame(height: Spacing.s)

            HStack(spacing: Spacing.s) {
                MoodImage(face: face, size: Spacing.moodFaceMediumSize)
                Text(face.label)
                    .font(.system(size: FontSize.s, weight: .semibold))
                    .foregroundStyle(face.color)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
    }
}
