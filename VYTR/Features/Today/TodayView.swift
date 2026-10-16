import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Meal.eatenAt, order: .reverse)
    private var allMeals: [Meal]

    @Query(sort: \Workout.scheduledAt, order: .forward)
    private var allWorkouts: [Workout]

    @AppStorage(DailyGoals.caloriesKey) private var calorieGoal = DailyGoals.defaultCalories
    @AppStorage(DailyGoals.proteinKey)  private var proteinGoal = DailyGoals.defaultProtein
    @AppStorage(DailyGoals.carbsKey)    private var carbsGoal   = DailyGoals.defaultCarbs
    @AppStorage(DailyGoals.fatKey)      private var fatGoal     = DailyGoals.defaultFat

    // Filtering in memory rather than in a predicate keeps the date logic
    // readable, and a personal day holds a handful of meals.
    private var todaysMeals: [Meal] {
        allMeals.filter { Calendar.current.isDateInToday($0.eatenAt) }
    }

    private var nextWorkout: Workout? {
        allWorkouts.first { !$0.isCompleted && $0.scheduledAt >= .now }
    }

    private var consumed: Int {
        todaysMeals.reduce(0) { $0 + $1.caloriesMidpoint }
    }

    private var hasEstimate: Bool {
        todaysMeals.contains(where: \.isEstimate)
    }

    private func total(_ keyPath: KeyPath<Meal, Double?>) -> Double {
        todaysMeals.reduce(0) { $0 + ($1[keyPath: keyPath] ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        header
                        CalorieRing(
                            consumed: consumed,
                            goal: calorieGoal,
                            isApproximate: hasEstimate
                        )
                        .padding(.vertical, Theme.Spacing.s)

                        macros
                        NextUpCard(workout: nextWorkout)
                        meals
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide)))
                    .font(.vytrTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(Date.now.formatted(.dateTime.day().month(.wide)))
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.s)
    }

    private var macros: some View {
        VStack(spacing: Theme.Spacing.m) {
            MacroBar(label: "Protein", grams: total(\.proteinGrams), goal: proteinGoal, color: Theme.Palette.protein)
            MacroBar(label: "Carbs",   grams: total(\.carbsGrams),   goal: carbsGoal,   color: Theme.Palette.carbs)
            MacroBar(label: "Fat",     grams: total(\.fatGrams),     goal: fatGoal,     color: Theme.Palette.fat)
        }
        .vytrCard()
    }

    private var meals: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "Today's meals")

            if todaysMeals.isEmpty {
                EmptyStateView(
                    systemImage: "camera.viewfinder",
                    title: "No meals logged yet",
                    message: "Meals you log today will appear here."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(todaysMeals) { meal in
                        MealRow(meal: meal)
                        if meal.id != todaysMeals.last?.id {
                            Divider().overlay(Theme.Palette.separator)
                        }
                    }
                }
            }
        }
        .vytrCard()
    }
}
