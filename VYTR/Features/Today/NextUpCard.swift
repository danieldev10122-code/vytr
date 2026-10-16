import SwiftUI

/// What is coming next: the upcoming workout, the next reminder, or an
/// honest note that nothing is scheduled.
struct NextUpCard: View {
    let workout: Workout?
    let reminder: Reminder?
    let reminderDate: Date?

    private var hasAnything: Bool {
        workout != nil || reminder != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Next up")

            if let workout {
                entry(
                    icon: "dumbbell",
                    accented: true,
                    title: workout.name,
                    detail: workout.scheduledAt.formatted(.relative(presentation: .named))
                )
            }

            if let reminder {
                if workout != nil {
                    Divider().overlay(Theme.Palette.separator)
                }
                entry(
                    icon: "bell",
                    accented: true,
                    title: reminder.title,
                    detail: detailText(for: reminderDate, fallback: reminder.timeText)
                )
            }

            if !hasAnything {
                entry(
                    icon: "calendar",
                    accented: false,
                    title: "Nothing scheduled",
                    detail: nil
                )
            }
        }
        .vytrCard()
    }

    private func detailText(for date: Date?, fallback: String) -> String {
        guard let date else { return fallback }
        let relative = date.formatted(.relative(presentation: .named))
        return "\(fallback) - \(relative)"
    }

    private func entry(icon: String, accented: Bool, title: String, detail: String?) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(accented ? Theme.Palette.accent : Theme.Palette.textTertiary)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(
                        accented ? Theme.Palette.accent.opacity(0.12) : Theme.Palette.surfaceRaised
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.vytrBody.weight(accented ? .medium : .regular))
                    .foregroundStyle(accented ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .lineLimit(2)
                if let detail {
                    Text(detail)
                        .font(.vytrCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
    }
}
