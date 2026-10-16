import SwiftUI

/// One thin protein / carbs / fat track.
struct MacroBar: View {
    let label: String
    let grams: Double
    let goal: Double
    let color: Color

    @ScaledMetric(relativeTo: .footnote) private var barHeight: CGFloat = 6

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(grams / goal, 1)
    }

    private var isOver: Bool { goal > 0 && grams > goal }

    /// Rounded, not truncated: 24.9g was reading as 24g.
    private var gramsText: String { "\(Int(grams.rounded()))g" }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.vytrLabel)
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.textTertiary)

                Spacer()

                Text(gramsText)
                    .font(.vytrNumericSmall)
                    .foregroundStyle(isOver ? Theme.Palette.warning : Theme.Palette.textPrimary)
                    .contentTransition(.numericText())

                Text("/ \(Int(goal.rounded()))g")
                    .font(.vytrLabel)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Palette.track)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.75), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress))
                }
            }
            .frame(height: barHeight)
            .animation(Theme.Motion.spring, value: progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(grams.rounded())) of \(Int(goal.rounded())) grams")
    }
}
