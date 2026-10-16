import SwiftUI

struct GoalsView: View {
    @AppStorage(DailyGoals.caloriesKey) private var calories = DailyGoals.defaultCalories
    @AppStorage(DailyGoals.proteinKey)  private var protein  = DailyGoals.defaultProtein
    @AppStorage(DailyGoals.carbsKey)    private var carbs    = DailyGoals.defaultCarbs
    @AppStorage(DailyGoals.fatKey)      private var fat      = DailyGoals.defaultFat

    /// Calories implied by the macro targets, at 4/4/9 kcal per gram.
    /// Shown as a sanity check, never enforced: these are personal targets,
    /// not a formula the app insists on.
    private var impliedCalories: Int {
        Int((protein * 4 + carbs * 4 + fat * 9).rounded())
    }

    private var drift: Int { impliedCalories - calories }

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    caloriesCard
                    macrosCard
                    checkCard
                    resetCard
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .navigationTitle("Daily targets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var caloriesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Calories")

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(calories.formatted(.number))
                    .font(.vytrNumber(44))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            stepper(
                down: { calories = max(800, calories - 50) },
                up:   { calories = min(6000, calories + 50) },
                caption: "50 kcal steps"
            )
        }
        .vytrCard()
    }

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Macros")
            macroRow("Protein", $protein, Theme.Palette.protein)
            Divider().overlay(Theme.Palette.separator)
            macroRow("Carbs", $carbs, Theme.Palette.carbs)
            Divider().overlay(Theme.Palette.separator)
            macroRow("Fat", $fat, Theme.Palette.fat)
        }
        .vytrCard()
    }

    private func macroRow(_ label: String, _ value: Binding<Double>, _ color: Color) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Circle().fill(color).frame(width: 6, height: 6)

            Text(label)
                .font(.vytrBody)
                .foregroundStyle(Theme.Palette.textSecondary)

            Spacer(minLength: Theme.Spacing.s)

            Button {
                value.wrappedValue = max(0, value.wrappedValue - 5)
            } label: {
                circleButton("minus")
            }
            .buttonStyle(.plain)

            Text("\(Int(value.wrappedValue))g")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(minWidth: 46)
                .contentTransition(.numericText())

            Button {
                value.wrappedValue = min(500, value.wrappedValue + 5)
            } label: {
                circleButton("plus")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var checkCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "Sanity check")

            Text("Your macros add up to \(impliedCalories.formatted(.number)) kcal.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textSecondary)

            Text(abs(drift) <= 100
                 ? "That matches your calorie target closely."
                 : "That is \(abs(drift).formatted(.number)) kcal \(drift > 0 ? "above" : "below") your calorie target. Not a problem, just worth knowing.")
                .font(.vytrCaption)
                .foregroundStyle(abs(drift) <= 100 ? Theme.Palette.accent : Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("These are targets you chose, not medical advice. VYTR never changes them on its own.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xs)
        }
        .vytrCard()
    }

    private var resetCard: some View {
        Button {
            withAnimation(Theme.Motion.spring) {
                calories = DailyGoals.defaultCalories
                protein  = DailyGoals.defaultProtein
                carbs    = DailyGoals.defaultCarbs
                fat      = DailyGoals.defaultFat
            }
        } label: {
            Text("Reset to defaults")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Theme.Palette.surfaceRaised))
        }
        .buttonStyle(.plain)
    }

    private func stepper(down: @escaping () -> Void, up: @escaping () -> Void, caption: String) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Button { withAnimation(Theme.Motion.spring) { down() } } label: {
                circleButton("minus")
            }
            .buttonStyle(.plain)

            Button { withAnimation(Theme.Motion.spring) { up() } } label: {
                circleButton("plus")
            }
            .buttonStyle(.plain)

            Text(caption)
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)

            Spacer(minLength: 0)
        }
    }

    private func circleButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.Palette.textSecondary)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Theme.Palette.surfaceRaised))
    }
}
