import SwiftUI

/// The headline readout of the Today screen.
struct CalorieRing: View {
    let consumed: Int
    let goal: Int
    /// True when any meal of the day was a photo estimate, so the total
    /// is labelled as approximate rather than exact.
    let isApproximate: Bool

    private let lineWidth: CGFloat = 12
    private let diameter: CGFloat = 172

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1)
    }

    private var remaining: Int { max(goal - consumed, 0) }

    /// Grouped digits ("1,850"), prefixed with ~ when any meal of the
    /// day was estimated from a photo rather than entered directly.
    private var consumedDisplay: String {
        let digits = consumed.formatted(.number)
        return isApproximate ? "~\(digits)" : digits
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.surfaceRaised, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Theme.Palette.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.spring, value: progress)

            VStack(spacing: 0) {
                Text(consumedDisplay)
                    .font(.vytrNumber(64))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.spring, value: consumed)

                Text("of \(goal) kcal")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)

                Text(remaining > 0 ? "\(remaining) left" : "goal reached")
                    .font(.vytrLabel)
                    .tracking(1.2)
                    .foregroundStyle(remaining > 0 ? Theme.Palette.textTertiary : Theme.Palette.accent)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories")
        .accessibilityValue("\(consumed) of \(goal) kilocalories")
    }
}
