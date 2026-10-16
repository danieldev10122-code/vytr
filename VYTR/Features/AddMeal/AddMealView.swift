import SwiftUI
import UIKit
import SwiftData

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var caloriesLow = ""
    @State private var caloriesHigh = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var eatenAt = Date.now
    @State private var imageData: Data?
    @State private var showCamera = false

    @State private var analysis: MealAnalysis?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var lowValue: Int? {
        guard let value = Int(caloriesLow), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && lowValue != nil && !isAnalyzing
    }

    private var hasRange: Bool { !caloriesHigh.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()
                form
                if isAnalyzing { analyzingOverlay }
            }
            .navigationTitle("Log a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .disabled(isAnalyzing)
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
            .alert(
                "Analysis failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: imageData) { _, _ in
                // A new photo invalidates an estimate made from the old one.
                analysis = nil
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                MealPhotoPicker(imageData: $imageData, showCamera: $showCamera)

                if imageData != nil {
                    analyzeButton
                }

                if let analysis {
                    AnalysisResultCard(analysis: analysis)
                }

                VStack(spacing: 0) {
                    FormField(label: "Name", placeholder: "Chicken and rice", text: $name)
                    divider
                    caloriesRow
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

    /// Opt-in, per photo. Nothing is uploaded without this tap.
    private var analyzeButton: some View {
        Button {
            Task { await analyze() }
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "sparkles")
                Text(analysis == nil ? "Analyze with AI" : "Analyze again")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Palette.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(Theme.Palette.accent))
        }
        .buttonStyle(.plain)
        .disabled(isAnalyzing)
    }

    private var caloriesRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            Text("Calories")
                .font(.vytrBody)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 86, alignment: .leading)

            TextField("0", text: $caloriesLow)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)

            if hasRange {
                Text("to")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                TextField("0", text: $caloriesHigh)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }

            Text("kcal")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(width: 30, alignment: .leading)
        }
        .font(.vytrBody)
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(.vertical, Theme.Spacing.s)
    }

    private var analyzingOverlay: some View {
        ZStack {
            Theme.Palette.background.opacity(0.88).ignoresSafeArea()
            VStack(spacing: Theme.Spacing.m) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.Palette.accent)
                Text("Analyzing photo")
                    .font(.vytrBody.weight(.medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Sending this photo to Google Gemini")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text("Retrying automatically if their servers are busy")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary.opacity(0.7))
            }
        }
        .transition(.opacity)
    }

    private var divider: some View {
        Divider().overlay(Theme.Palette.separator)
    }

    // MARK: - Actions

    private func analyze() async {
        guard let imageData else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let result = try await GeminiClient.analyze(imageData: imageData)
            apply(result)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// Fills the form from an estimate. Everything stays editable, and a
    /// field the user already typed into is not overwritten.
    private func apply(_ result: MealAnalysis) {
        withAnimation(Theme.Motion.spring) {
            analysis = result

            if trimmedName.isEmpty {
                name = result.mealName
            }

            caloriesLow = "\(result.totalCaloriesMin)"
            caloriesHigh = result.totalCaloriesMax == result.totalCaloriesMin
                ? ""
                : "\(result.totalCaloriesMax)"

            if let value = result.proteinGrams, protein.isEmpty {
                protein = "\(Int(value.rounded()))"
            }
            if let value = result.carbsGrams, carbs.isEmpty {
                carbs = "\(Int(value.rounded()))"
            }
            if let value = result.fatGrams, fat.isEmpty {
                fat = "\(Int(value.rounded()))"
            }
        }
    }

    private func save() {
        guard let low = lowValue else { return }
        let high = Int(caloriesHigh) ?? low

        let meal = Meal(
            name: trimmedName,
            eatenAt: eatenAt,
            caloriesMin: low,
            caloriesMax: high,
            proteinGrams: Double(protein),
            carbsGrams: Double(carbs),
            fatGrams: Double(fat),
            photo: imageData,
            source: analysis == nil ? .manual : .photoEstimate
        )

        context.insert(meal)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
