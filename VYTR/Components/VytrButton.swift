import SwiftUI

/// The one action button in the app.
///
/// The same capsule was written out by hand on six screens, each with
/// slightly different padding and its own idea of what disabled looks
/// like, and none of them showed a pressed state. This replaces all of
/// them and carries the three states an action can be in: ready, busy,
/// and unavailable.
struct VytrButton: View {

    enum Kind {
        case primary
        case secondary
        case destructive
    }

    let title: String
    var systemImage: String?
    var kind: Kind = .primary
    var isLoading: Bool = false
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    private var foreground: Color {
        guard isEnabled else { return Theme.Palette.textTertiary }
        switch kind {
        case .primary:     return Theme.Palette.background
        case .secondary:   return Theme.Palette.textSecondary
        case .destructive: return Theme.Palette.danger
        }
    }

    private var background: Color {
        guard isEnabled else { return Theme.Palette.surfaceRaised }
        switch kind {
        case .primary:     return Theme.Palette.accent
        case .secondary:   return Theme.Palette.surfaceRaised
        case .destructive: return Theme.Palette.danger.opacity(0.14)
        }
    }

    var body: some View {
        Button(action: action) {
            VytrButtonLabel(
                title: isLoading ? "Working" : title,
                systemImage: systemImage,
                isLoading: isLoading,
                foreground: foreground,
                background: background
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isLoading || !isEnabled)
        .animation(Theme.Motion.gentle, value: isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

/// The capsule itself, separated out so a control that cannot be a
/// Button - a ShareLink, which insists on providing its own - still
/// looks like every other action in the app rather than a near miss.
struct VytrButtonLabel: View {
    let title: String
    var systemImage: String?
    var isLoading: Bool = false
    var foreground: Color = Theme.Palette.background
    var background: Color = Theme.Palette.accent

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(foreground)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.vytrHeadline)
            }

            Text(title)
                .font(.vytrHeadline)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Capsule().fill(background))
        .contentShape(Capsule())
    }
}

/// Dims and shrinks very slightly while held. Enough to feel answered,
/// not enough to look like a toy.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

/// For rows and cards that act as buttons, where a capsule would be wrong
/// but the press should still register.
extension View {
    func pressable() -> some View {
        buttonStyle(PressableButtonStyle())
    }
}
