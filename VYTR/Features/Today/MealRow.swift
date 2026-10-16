import SwiftUI

struct MealRow: View {
    let meal: Meal

    private var timeText: String {
        meal.eatenAt.formatted(date: .omitted, time: .shortened)
    }

    private var accessibilityText: String {
        var parts = [meal.name, timeText]
        parts.append(meal.isEstimate
                     ? "estimated \(meal.caloriesMin) to \(meal.caloriesMax) kilocalories"
                     : "\(meal.caloriesMin) kilocalories")
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            MealThumbnail(meal: meal)

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name)
                    .font(.vytrBody.weight(.medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.s) {
                    Text(timeText)

                    if meal.isEstimate {
                        Text("ESTIMATE")
                            .font(.vytrLabel)
                            .tracking(0.8)
                            .foregroundStyle(Theme.Palette.accent.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Theme.Palette.accentMuted)
                            )
                    }
                }
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.s)

            VStack(alignment: .trailing, spacing: 1) {
                Text(meal.caloriesDisplay)
                    .font(.vytrNumeric)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("kcal")
                    .font(.vytrLabel)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}
