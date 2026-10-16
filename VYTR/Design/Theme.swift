import SwiftUI

/// Single source of truth for the Dark Premium look.
/// Nothing in the app hard-codes a colour, spacing or radius.
enum Theme {

    enum Palette {
        /// Page background. Near-black, slightly cool.
        static let background = Color(red: 0.04, green: 0.05, blue: 0.06)
        /// Cards sitting on the background.
        static let surface = Color(red: 0.08, green: 0.09, blue: 0.11)
        /// Tracks, wells and pressed states.
        static let surfaceRaised = Color(red: 0.17, green: 0.18, blue: 0.22)

        /// The one accent. Reserved for progress and positive state.
        static let accent = Color(red: 0.72, green: 0.95, blue: 0.40)

        static let protein = Color(red: 0.45, green: 0.78, blue: 1.00)
        static let carbs   = Color(red: 0.98, green: 0.76, blue: 0.38)
        static let fat     = Color(red: 0.86, green: 0.55, blue: 0.95)

        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.55)
        static let textTertiary  = Color.white.opacity(0.30)

        /// Thin tracks need more contrast than a card edge to look
        /// deliberate when the value is zero.
        static let track = Color.white.opacity(0.10)

        static let separator = Color.white.opacity(0.08)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s:  CGFloat = 8
        static let m:  CGFloat = 16
        static let l:  CGFloat = 24
        static let xl: CGFloat = 32
        /// Clears the floating tab bar, which overlays content rather
        /// than pushing it up.
        static let tabBarClearance: CGFloat = 96
    }

    enum Radius {
        static let card: CGFloat = 20
        static let control: CGFloat = 14
    }

    enum Motion {
        /// Used for every value change the user should notice.
        static let spring = Animation.spring(response: 0.55, dampingFraction: 0.82)
    }
}

extension Font {
    /// Large thin rounded numerals - the signature of the calorie readouts.
    static func vytrNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .thin, design: .rounded)
    }

    static let vytrTitle   = Font.system(size: 20, weight: .semibold)
    static let vytrBody    = Font.system(size: 15, weight: .regular)
    static let vytrCaption = Font.system(size: 13, weight: .regular)
    /// Small all-caps label with wide tracking.
    static let vytrLabel   = Font.system(size: 11, weight: .semibold)
}

// MARK: - Card

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.separator, lineWidth: 1)
            )
    }
}

extension View {
    func vytrCard() -> some View { modifier(CardModifier()) }
}

// MARK: - Section label

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.vytrLabel)
            .tracking(1.4)
            .foregroundStyle(Theme.Palette.textTertiary)
    }
}
