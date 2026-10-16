import SwiftUI

/// Single source of truth for the Dark Premium look.
/// Nothing in the app hard-codes a colour, spacing, radius or duration.
enum Theme {

    enum Palette {
        /// Page background. Near-black, slightly cool.
        static let background = Color(red: 0.04, green: 0.05, blue: 0.06)

        /// Cards sitting on the background. Two stops rather than one: a
        /// flat fill on a flat background reads as a rectangle, while a
        /// few percent of lift along the top edge reads as a surface.
        static let surfaceTop = Color(red: 0.105, green: 0.115, blue: 0.135)
        static let surface    = Color(red: 0.075, green: 0.085, blue: 0.10)

        /// Tracks, wells and pressed states.
        static let surfaceRaised = Color(red: 0.17, green: 0.18, blue: 0.22)

        /// The one accent. Reserved for progress and positive state.
        static let accent = Color(red: 0.72, green: 0.95, blue: 0.40)
        /// Used behind the accent at low opacity, for icon wells.
        static let accentMuted = Color(red: 0.72, green: 0.95, blue: 0.40).opacity(0.12)

        static let protein = Color(red: 0.45, green: 0.78, blue: 1.00)
        static let carbs   = Color(red: 0.98, green: 0.76, blue: 0.38)
        static let fat     = Color(red: 0.86, green: 0.55, blue: 0.95)

        /// Warnings and destructive actions. Named rather than reaching
        /// for .red, so the dark palette stays deliberate.
        static let warning = Color(red: 1.00, green: 0.72, blue: 0.35)
        static let danger  = Color(red: 1.00, green: 0.42, blue: 0.42)

        static let textPrimary   = Color.white
        static let textSecondary = Color.white.opacity(0.62)
        static let textTertiary  = Color.white.opacity(0.38)

        /// Thin tracks need more contrast than a card edge to look
        /// deliberate when the value is zero.
        static let track = Color.white.opacity(0.10)

        /// Hairlines. Brighter along a card's top edge than its bottom,
        /// which is what makes an edge look lit rather than drawn.
        static let separator  = Color.white.opacity(0.08)
        static let edgeLight  = Color.white.opacity(0.10)
        static let edgeShadow = Color.white.opacity(0.03)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s:  CGFloat = 8
        static let m:  CGFloat = 16
        static let l:  CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 22
        static let control: CGFloat = 14
        static let thumbnail: CGFloat = 12
    }

    enum Motion {
        /// A value the user should watch change: a ring, a bar, a total.
        static let spring = Animation.spring(response: 0.55, dampingFraction: 0.82)
        /// Direct manipulation: taps, toggles, selection.
        static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.86)
        /// Appearance and disappearance, where a spring would wobble.
        static let gentle = Animation.easeInOut(duration: 0.22)
    }
}

// MARK: - Typography

/// Every face is built from a Dynamic Type text style rather than a fixed
/// point size, so the whole app follows the reader's text size setting.
/// Fixed sizes are reserved for the large numerals, which scale through
/// @ScaledMetric at their call sites instead.
extension Font {
    static let vytrTitle    = Font.system(.title3,      design: .default, weight: .semibold)
    static let vytrHeadline = Font.system(.subheadline, design: .default, weight: .semibold)
    static let vytrBody     = Font.system(.subheadline, design: .default, weight: .regular)
    static let vytrCaption  = Font.system(.footnote,    design: .default, weight: .regular)
    static let vytrLabel    = Font.system(.caption2,    design: .default, weight: .semibold)

    /// Figures that sit beside text: macro grams, calorie counts in rows.
    static let vytrNumeric  = Font.system(.subheadline, design: .rounded, weight: .medium)
    static let vytrNumericSmall = Font.system(.caption,  design: .rounded, weight: .medium)

    /// Large thin rounded numerals - the signature of the headline
    /// readouts. Size comes from a @ScaledMetric so it still responds to
    /// the reader's text size.
    static func vytrNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .thin, design: .rounded)
    }
}

// MARK: - Card

private struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.Palette.surfaceTop, Theme.Palette.surface],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.Palette.edgeLight, Theme.Palette.edgeShadow],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            // Soft and wide rather than tight and dark: on a near-black
            // background a hard shadow reads as a seam.
            .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func vytrCard(padding: CGFloat = Theme.Spacing.m) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Section label

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.vytrLabel)
            .tracking(1.4)
            .foregroundStyle(Theme.Palette.textTertiary)
            .accessibilityAddTraits(.isHeader)
    }
}
