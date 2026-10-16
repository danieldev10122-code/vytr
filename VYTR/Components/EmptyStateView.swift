import SwiftUI

/// Shown wherever there is no data yet. An empty screen should still look
/// designed, and should say what to do next.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.Palette.textTertiary)
                .padding(.bottom, Theme.Spacing.xs)

            Text(title)
                .font(.vytrBody.weight(.medium))
                .foregroundStyle(Theme.Palette.textSecondary)

            Text(message)
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
    }
}
