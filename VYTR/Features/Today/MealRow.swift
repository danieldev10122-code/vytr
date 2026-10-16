import SwiftUI
import UIKit

struct MealRow: View {
    let meal: Meal

    private var timeText: String {
        meal.eatenAt.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.vytrBody.weight(.medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.s) {
                    Text(timeText)
                    if meal.isEstimate {
                        Text("estimate")
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.s)

            Text("\(meal.caloriesDisplay) kcal")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    @ViewBuilder
    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.Palette.surfaceRaised)
            .frame(width: 40, height: 40)
            .overlay {
                if let data = meal.photo, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
    }
}
