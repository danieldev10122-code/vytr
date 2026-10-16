import SwiftUI
import UIKit
import SwiftData

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var eatenAt = Date.now
    @State private var imageData: Data?
    @State private var showCamera = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var calorieValue: Int? {
        guard let value = Int(calories), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && calorieValue != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        MealPhotoPicker(imageData: $imageData, showCamera: $showCamera)

                        VStack(spacing: 0) {
                            FormField(
                                label: "Name",
                                placeholder: "Chicken and rice",
                                text: $name
                            )
                            divider
                            FormField(
                                label: "Calories",
                                placeholder: "0",
                                text: $calories,
                                suffix: "kcal",
                                keyboard: .numberPad
                            )
                        }
                        .vytrCard()

                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            SectionLabel(text: "Macros (optional)")
                            VStack(spacing: 0) {
                                FormField(label: "Protein", placeholder: "0", text: $protein, suffix: "g", keyboard: .numberPad)
                                divider
                                FormField(label: "Carbs", placeholder: "0", text: $carbs, suffix: "g", keyboard: .numberPad)
                                divider
                                FormField(label: "Fat", placeholder: "0", text: $fat, suffix: "g", keyboard: .numberPad)
                            }
                        }
                        .vytrCard()

                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            SectionLabel(text: "When")
                            DatePicker("", selection: $eatenAt, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Theme.Palette.accent)
                        }
                        .vytrCard()
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationTitle("Log a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Theme.Palette.accent : Theme.Palette.textTertiary)
                        .disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(imageData: $imageData)
                    .ignoresSafeArea()
            }
        }
    }

    private var divider: some View {
        Divider().overlay(Theme.Palette.separator)
    }

    private func save() {
        guard let kcal = calorieValue else { return }

        // A manual entry is a stated value, not an estimate, so both
        // bounds of the range are the same number.
        let meal = Meal(
            name: trimmedName,
            eatenAt: eatenAt,
            caloriesMin: kcal,
            caloriesMax: kcal,
            proteinGrams: Double(protein),
            carbsGrams: Double(carbs),
            fatGrams: Double(fat),
            photo: imageData,
            source: .manual
        )

        context.insert(meal)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
