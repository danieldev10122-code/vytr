import SwiftUI

/// The headline readout of the Today screen.
struct CalorieRing: View {
    let consumed: Int
    let goal: Int
    /// True when any meal of the day was a photo estimate, so the total
    /// is labelled as approximate rather than exact.
    let isApproximate: Bool

    /// Scaled rather than fixed, so the ring grows with the reader's text
    /// size instead of clipping the figure inside it.
    @ScaledMetric(relativeTo: .largeTitle) private var diameter: CGFloat = 176
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 60
    @ScaledMetric(relativeTo: .largeTitle) private var lineWidth: CGFloat = 13

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1)
    }

    /// Kept separate from `progress`, which is clamped for the arc. Going
    /// over the target is worth showing rather than hiding at a full ring.
    private var isOver: Bool { consumed > goal && goal > 0 }

    private var remaining: Int { max(goal - consumed, 0) }

    /// Grouped digits ("1,850"), prefixed with ~ when any meal of the
    /// day was estimated from a photo rather than entered directly.
    private var consumedDisplay: String {
        let digits = consumed.formatted(.number)
        return isApproximate ? "~\(digits)" : digits
    }

    private var footnote: String {
        if isOver { return "\((consumed - goal).formatted(.number)) over" }
        if remaining == 0 { return "goal reached" }
        return "\(remaining.formatted(.number)) left"
    }

    private var footnoteColor: Color {
        if isOver { return Theme.Palette.warning }
        if remaining == 0 { return Theme.Palette.accent }
        return Theme.Palette.textTertiary
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.surfaceRaised, lineWidth: lineWidth)

            // A soft copy of the arc underneath, so the accent appears to
            // sit above the track rather than be painted into it.
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Theme.Palette.accent.opacity(0.35),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .blur(radius: 7)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOver ? Theme.Palette.warning : Theme.Palette.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(consumedDisplay)
                    .font(.vytrNumber(numberSize))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("of \(goal) kcal")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)

                Text(footnote.uppercased())
                    .font(.vytrLabel)
                    .tracking(1.2)
                    .foregroundStyle(footnoteColor)
                    .padding(.top, Theme.Spacing.s)
            }
            .padding(.horizontal, lineWidth * 2)
        }
        .frame(width: diameter, height: diameter)
        .animation(Theme.Motion.spring, value: progress)
        .animation(Theme.Motion.spring, value: consumed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories today")
        .accessibilityValue(
            "\(isApproximate ? "about " : "")\(consumed) of \(goal) kilocalories, \(footnote)"
        )
    }
}
