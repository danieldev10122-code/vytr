import SwiftUI

/// The single "what is next" card: the upcoming workout, or an invitation
/// to plan one when the schedule is empty.
struct NextUpCard: View {
    let workout: Workout?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "Next up")

            if let workout {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Theme.Palette.accent)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle().fill(Theme.Palette.accent.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name)
                            .font(.vytrBody.weight(.medium))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(workout.scheduledAt.formatted(.relative(presentation: .named)))
                            .font(.vytrCaption)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }

                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.Palette.surfaceRaised))

                    Text("Nothing scheduled")
                        .font(.vytrBody)
                        .foregroundStyle(Theme.Palette.textSecondary)

                    Spacer(minLength: 0)
                }
            }
        }
        .vytrCard()
    }
}
