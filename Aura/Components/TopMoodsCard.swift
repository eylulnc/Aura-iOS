import SwiftUI

struct TopMoodsCard: View {
    let topMoods: [(MoodFace, Int)]

    @Environment(\.auraColors) private var colors

    var body: some View {
        let maxCount = topMoods.map(\.1).max() ?? 1

        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Top Moods")
                .font(.system(size: FontSize.s, weight: .medium))
                .foregroundStyle(colors.textPrimary)

            ForEach(topMoods, id: \.0.id) { face, count in
                HStack(spacing: Spacing.m) {
                    MoodImage(face: face, size: Spacing.moodFaceSmallSize)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(face.label)
                                .font(.system(size: FontSize.s))
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: FontSize.s))
                                .foregroundStyle(colors.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colors.border)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(face.color)
                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .padding(Spacing.l)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
    }
}
