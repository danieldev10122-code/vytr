import SwiftUI

/// One thin protein / carbs / fat track.
struct MacroBar: View {
    let label: String
    let grams: Double
    let goal: Double
    let color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(grams / goal, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(label)
                    .font(.vytrLabel)
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.textTertiary)
                Spacer()
                Text("\(Int(grams))g")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Palette.surfaceRaised)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(Theme.Motion.spring, value: progress)
                }
            }
            .frame(height: 5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(grams)) of \(Int(goal)) grams")
    }
}
