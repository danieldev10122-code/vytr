import SwiftUI
import SwiftData
import Combine

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

    /// One sheet, chosen by case. Two .sheet modifiers on the same view
    /// is not something SwiftUI guarantees to honour, and it is the kind
    /// of arrangement that works until it quietly stops.
    private enum ActiveSheet: Identifiable {
        case addMeal
        case mealDetail(Meal)

        var id: String {
            switch self {
            case .addMeal: return "add"
            case .mealDetail(let meal): return "detail-\(meal.persistentModelID)"
            }
        }
    }

    @State private var activeSheet: ActiveSheet?

    /// Re-read every minute so the screen rolls over at midnight instead
    /// of showing yesterday until the app is relaunched.
    @State private var now = Date.now
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var todaysMeals: [Meal] {
        allMeals.filter { Calendar.current.isDate($0.eatenAt, inSameDayAs: now) }
    }

    private var nextWorkout: Workout? {
        allWorkouts.first { !$0.isCompleted && $0.scheduledAt >= now }
    }

    private var nextReminder: (reminder: Reminder, date: Date)? {
        allReminders
            .compactMap { reminder in
                reminder.nextOccurrence(after: now).map { (reminder: reminder, date: $0) }
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
                        summaryCard
                        VytrButton(title: "Log a meal", systemImage: "camera.fill") {
                            activeSheet = .addMeal
                        }
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
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(ticker) { now = $0 }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addMeal:
                    AddMealView(existing: nil)
                case .mealDetail(let meal):
                    MealDetailView(meal: meal)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(now.formatted(.dateTime.weekday(.wide)))
                    .font(.vytrTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(now.formatted(.dateTime.day().month(.wide)))
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer()

            if !todaysMeals.isEmpty {
                Text("\(todaysMeals.count) logged")
                    .font(.vytrLabel)
                    .tracking(1)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.top, Theme.Spacing.s)
        .accessibilityElement(children: .combine)
    }

    /// The ring and the macros read as one instrument rather than two
    /// unrelated widgets, which is the difference between a dashboard and
    /// a pile of components.
    private var summaryCard: some View {
        VStack(spacing: Theme.Spacing.l) {
            CalorieRing(
                consumed: consumed,
                goal: calorieGoal,
                isApproximate: hasEstimate
            )
            .padding(.top, Theme.Spacing.s)

            Divider().overlay(Theme.Palette.separator)

            VStack(spacing: Theme.Spacing.m) {
                MacroBar(label: "Protein", grams: total(\.proteinGrams), goal: proteinGoal, color: Theme.Palette.protein)
                MacroBar(label: "Carbs",   grams: total(\.carbsGrams),   goal: carbsGoal,   color: Theme.Palette.carbs)
                MacroBar(label: "Fat",     grams: total(\.fatGrams),     goal: fatGoal,     color: Theme.Palette.fat)
            }
        }
        .vytrCard(padding: Theme.Spacing.l)
    }

    private var meals: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "Today's meals")

            if todaysMeals.isEmpty {
                EmptyStateView(
                    systemImage: "camera.viewfinder",
                    title: "No meals logged yet",
                    message: "Photograph a meal and VYTR will estimate it, or enter the numbers yourself.",
                    actionTitle: "Log a meal",
                    action: { activeSheet = .addMeal }
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(todaysMeals) { meal in
                        Button {
                            activeSheet = .mealDetail(meal)
                        } label: {
                            MealRow(meal: meal)
                        }
                        .pressable()
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
            try? context.save()
        }
    }
}
