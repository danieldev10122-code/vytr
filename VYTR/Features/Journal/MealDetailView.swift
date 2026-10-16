import SwiftUI
import UIKit
import SwiftData

struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let meal: Meal

    @State private var showDeleteConfirm = false
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        photo
                        summary
                        macros
                        deleteButton
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit") { showEditor = true }
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            .sheet(isPresented: $showEditor) {
                AddMealView(existing: meal)
            }
            .confirmationDialog(
                "Delete this meal?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    context.delete(meal)
                    try? context.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let data = meal.photo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: meal.isEstimate ? "Estimated" : "Entered")
                Spacer()
                Text(meal.eatenAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(meal.caloriesDisplay)
                    .font(.vytrNumber(40))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("kcal")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            if meal.isEstimate {
                Text("This range came from a photo and was not measured. The daily total uses its midpoint.")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .vytrCard()
    }

    private var macros: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Macros")
            macroRow("Protein", meal.proteinGrams, Theme.Palette.protein)
            Divider().overlay(Theme.Palette.separator)
            macroRow("Carbs", meal.carbsGrams, Theme.Palette.carbs)
            Divider().overlay(Theme.Palette.separator)
            macroRow("Fat", meal.fatGrams, Theme.Palette.fat)
        }
        .vytrCard()
    }

    /// A macro that was never recorded reads as "not recorded" rather than
    /// 0g, because an unknown value is not a measured zero.
    private func macroRow(_ label: String, _ grams: Double?, _ color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.vytrBody)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            if let grams {
                Text("\(Int(grams.rounded()))g")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Palette.textPrimary)
            } else {
                Text("not recorded")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Text("Delete meal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(Color.red.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}
