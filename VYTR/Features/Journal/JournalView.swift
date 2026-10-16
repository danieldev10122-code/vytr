import SwiftUI
import SwiftData

struct JournalView: View {
    @Query(sort: \Meal.eatenAt, order: .reverse)
    private var meals: [Meal]

    @State private var query = ""
    @State private var selected: Meal?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [Meal] {
        guard !trimmedQuery.isEmpty else { return meals }
        return meals.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    /// Grouped by calendar day, newest first. Grouping in memory keeps the
    /// date handling in one readable place, and a personal journal is
    /// small enough that it costs nothing.
    private var days: [(date: Date, meals: [Meal])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.eatenAt) }
            .map { (date: $0.key, meals: $0.value.sorted { $0.eatenAt > $1.eatenAt }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                if meals.isEmpty {
                    EmptyStateView(
                        systemImage: "square.grid.2x2",
                        title: "Nothing logged yet",
                        message: "Meals you log will be collected here, newest first."
                    )
                    .padding(.horizontal, Theme.Spacing.xl)
                } else if filtered.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No matches",
                        message: "Nothing in your journal matches \"\(trimmedQuery)\"."
                    )
                    .padding(.horizontal, Theme.Spacing.xl)
                } else {
                    content
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search meals"
            )
            .sheet(item: $selected) { meal in
                MealDetailView(meal: meal)
            }
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.l, pinnedViews: [.sectionHeaders]) {
                ForEach(days, id: \.date) { day in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(day.meals) { meal in
                                Button {
                                    selected = meal
                                } label: {
                                    MealRow(meal: meal)
                                }
                                .buttonStyle(.plain)

                                if meal.id != day.meals.last?.id {
                                    Divider().overlay(Theme.Palette.separator)
                                }
                            }
                        }
                        .vytrCard()
                    } header: {
                        DayHeader(date: day.date, meals: day.meals)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

/// A day's date and its total, so scrolling back through the journal
/// answers "how did that day go" without opening anything.
private struct DayHeader: View {
    let date: Date
    let meals: [Meal]

    private var title: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var total: Int {
        meals.reduce(0) { $0 + $1.caloriesMidpoint }
    }

    private var isApproximate: Bool {
        meals.contains(where: \.isEstimate)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.vytrBody.weight(.semibold))
                .foregroundStyle(Theme.Palette.textPrimary)

            Spacer()

            Text("\(isApproximate ? "~" : "")\(total.formatted(.number)) kcal")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Palette.background)
    }
}
