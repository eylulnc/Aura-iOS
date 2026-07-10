import SwiftUI

struct MoodTrendCard: View {
    let weekEntries: [MoodEntry?]

    @Environment(\.auraColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("7-Day Trend")
                .font(.system(size: FontSize.s, weight: .bold))
                .foregroundStyle(colors.textPrimary)
                .padding(.bottom, Spacing.m)

            TrendCanvas(weekEntries: weekEntries, accentColor: colors.accent, surfaceColor: colors.surface)
                .frame(height: 90)

            Spacer().frame(height: Spacing.xs)

            HStack {
                ForEach(dayLabels(), id: \.self) { label in
                    Text(label)
                        .font(.system(size: FontSize.xs))
                        .foregroundStyle(colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Spacing.l)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
    }

    private func dayLabels() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let today = Date()
        return (0..<7).map { i in
            let daysAgo = 6 - i
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            return formatter.string(from: date)
        }
    }
}

private struct TrendCanvas: View {
    let weekEntries: [MoodEntry?]
    let accentColor: Color
    let surfaceColor: Color

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let padH: CGFloat = 8
            let padV: CGFloat = 8
            let chartW = w - padH * 2
            let chartH = h - padV * 2
            let bottomY = padV + chartH

            func xFor(_ i: Int) -> CGFloat { padH + (CGFloat(i) / 6.0) * chartW }
            func yFor(_ moodId: Int) -> CGFloat {
                let v = MOOD_VALENCE[moodId] ?? 0
                let norm = CGFloat((v + 2) / 4)
                return padV + chartH - norm * chartH
            }

            // Zone bands
            ctx.fill(
                Path(CGRect(x: padH, y: padV, width: chartW, height: chartH * 0.38)),
                with: .color(Color(hex: "#1D9E75").opacity(0.07))
            )
            ctx.fill(
                Path(CGRect(x: padH, y: padV + chartH * 0.62, width: chartW, height: chartH * 0.38)),
                with: .color(Color(hex: "#378ADD").opacity(0.07))
            )

            // Segments of consecutive non-nil entries
            var segments: [[Int]] = []
            var current: [Int] = []
            for (i, entry) in weekEntries.enumerated() {
                if entry != nil { current.append(i) }
                else if !current.isEmpty { segments.append(current); current = [] }
            }
            if !current.isEmpty { segments.append(current) }

            for seg in segments {
                guard !seg.isEmpty else { continue }
                let pts = seg.map { i in CGPoint(x: xFor(i), y: yFor(weekEntries[i]!.mood)) }

                // Gradient fill
                var areaPath = Path()
                areaPath.move(to: pts[0])
                pts.dropFirst().forEach { areaPath.addLine(to: $0) }
                areaPath.addLine(to: CGPoint(x: pts.last!.x, y: bottomY))
                areaPath.addLine(to: CGPoint(x: pts.first!.x, y: bottomY))
                areaPath.closeSubpath()
                ctx.fill(areaPath, with: .linearGradient(
                    Gradient(colors: [accentColor.opacity(0.28), accentColor.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: padV),
                    endPoint: CGPoint(x: 0, y: bottomY)
                ))

                // Line
                var linePath = Path()
                linePath.move(to: pts[0])
                pts.dropFirst().forEach { linePath.addLine(to: $0) }
                ctx.stroke(linePath, with: .color(accentColor),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }

            // Dots
            for (i, entry) in weekEntries.enumerated() {
                guard let entry else { continue }
                let center = CGPoint(x: xFor(i), y: yFor(entry.mood))
                let r: CGFloat = 5
                let moodColor = getMoodFace(id: entry.mood).color
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                         with: .color(moodColor))
                ctx.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                           with: .color(surfaceColor),
                           style: StrokeStyle(lineWidth: 2.5))
            }
        }
    }
}
