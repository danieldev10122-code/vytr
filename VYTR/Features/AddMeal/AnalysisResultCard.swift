import SwiftUI

/// Shows what the model claims it saw, so the numbers in the form are
/// traceable to something rather than appearing from nowhere.
struct AnalysisResultCard: View {
    let analysis: MealAnalysis

    private var confidenceColor: Color {
        switch analysis.confidence {
        case .high:   return Theme.Palette.accent
        case .medium: return Theme.Palette.carbs
        case .low:    return Theme.Palette.fat
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                SectionLabel(text: "Detected")
                Spacer()
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 6, height: 6)
                    Text(analysis.confidence.label)
                        .font(.vytrLabel)
                        .tracking(1)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }

            if analysis.isEmpty {
                Text("No food could be identified in this photo.")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(analysis.items) { item in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.vytrBody)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                Text(item.portion)
                                    .font(.vytrCaption)
                                    .foregroundStyle(Theme.Palette.textTertiary)
                            }
                            Spacer(minLength: Theme.Spacing.s)
                            Text("\(item.caloriesMin)-\(item.caloriesMax)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
            }

            Text("Estimated from a photo, not measured. Edit anything below.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)

            if let notes = analysis.notes, !notes.isEmpty {
                Text(notes)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .vytrCard()
    }
}
