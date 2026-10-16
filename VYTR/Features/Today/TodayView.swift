import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Meal.eatenAt, order: .reverse)
    private var allMeals: [Meal]

    @Query(sort: \Workout.scheduledAt, order: .forward)
    private var allWorkouts: [Workout]

    @Query private var allReminders: [Reminder]

    @AppStorage(DailyGoals.caloriesKey) private var calorieGoal = DailyGoals.defaultCalories
    @AppStorage(DailyGoals.proteinKey)  private var proteinGoal = DailyGoals.defaultProtein
    @AppStorage(DailyGoals.carbsKey)    private var carbsGoal   = DailyGoals.defaultCarbs
    @AppStorage(DailyGoals.fatKey)      private var fatGoal     = DailyGoals.defaultFat

    @State private var showAddMeal = false
    @State private var selectedMeal: Meal?

    // Filtering in memory rather than in a predicate keeps the date logic
    // readable, and a personal day holds a handful of meals.
    private var todaysMeals: [Meal] {
        allMeals.filter { Calendar.current.isDateInToday($0.eatenAt) }
    }

    private var nextWorkout: Workout? {
        allWorkouts.first { !$0.isCompleted && $0.scheduledAt >= .now }
    }

    /// The reminder that fires soonest, so Today answers "what is next"
    /// without opening another screen.
    private var nextReminder: (reminder: Reminder, date: Date)? {
        allReminders
            .compactMap { reminder in
                reminder.nextOccurrence().map { (reminder: reminder, date: $0) }
            }
            .min { $0.date < $1.date }
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

                        logMealButton
                        macros
                        NextUpCard(
                            workout: nextWorkout,
                            reminder: nextReminder?.reminder,
                            reminderDate: nextReminder?.date
                        )
                        meals
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    // TabView already insets the scroll view for the floating
                    // tab bar, so this is breathing room only.
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddMeal) {
                AddMealView()
            }
            .sheet(item: $selectedMeal) { meal in
                MealDetailView(meal: meal)
            }
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

    /// The primary action of the whole app, so it gets the accent and the
    /// full width rather than a small icon tucked in a corner.
    private var logMealButton: some View {
        Button {
            showAddMeal = true
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log a meal")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Theme.Palette.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Capsule().fill(Theme.Palette.accent))
        }
        .buttonStyle(.plain)
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
                    message: "Tap Log a meal to add your first one."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(todaysMeals) { meal in
                        Button {
                            selectedMeal = meal
                        } label: {
                            MealRow(meal: meal)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                                Button(role: .destructive) {
                                    delete(meal)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        if meal.id != todaysMeals.last?.id {
                            Divider().overlay(Theme.Palette.separator)
                        }
                    }
                }
            }
        }
        .vytrCard()
    }

    private func delete(_ meal: Meal) {
        withAnimation(Theme.Motion.spring) {
            context.delete(meal)
        }
    }
}
