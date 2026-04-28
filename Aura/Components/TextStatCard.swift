import SwiftUI

struct TextStatCard: View {
    let label: String
    let value: String
    let unit: String?
    let valueColor: Color
    let backgroundColor: Color
    var infoText: String? = nil

    @Environment(\.auraColors) private var colors
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(label)
                    .font(.system(size: FontSize.s))
                    .foregroundStyle(colors.textSecondary)

                if let infoText {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: FontSize.xs))
                            .foregroundStyle(colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .alert(label, isPresented: $showInfo) {
                        Button("Got it", role: .cancel) {}
                    } message: {
                        Text(infoText)
                    }
                }
            }

            Spacer().frame(height: Spacing.s)

            Text(value)
                .font(.system(size: FontSize.xl, weight: .bold))
                .foregroundStyle(valueColor)

            if let unit {
                Text(unit)
                    .font(.system(size: FontSize.s))
                    .foregroundStyle(colors.textSecondary)
            } else {
                Spacer().frame(height: FontSize.s)
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusCard))
    }
}
