import SwiftUI

/// Shown wherever there is no data yet. An empty screen should still look
/// designed, should say what to do next, and where there is an obvious
/// next step it should offer it rather than describe it.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @ScaledMetric(relativeTo: .title2) private var iconWell: CGFloat = 54

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: systemImage)
                .font(.system(.title3, design: .default, weight: .light))
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(width: iconWell, height: iconWell)
                .background(
                    Circle().fill(Theme.Palette.surfaceRaised.opacity(0.5))
                )
                .padding(.bottom, Theme.Spacing.xs)

            Text(title)
                .font(.vytrHeadline)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                VytrButton(title: actionTitle, kind: .secondary, action: action)
                    .padding(.top, Theme.Spacing.s)
                    .padding(.horizontal, Theme.Spacing.l)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
        .accessibilityElement(children: .contain)
    }
}
