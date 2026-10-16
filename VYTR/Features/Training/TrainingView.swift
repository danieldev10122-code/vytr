import SwiftUI
import UIKit
import SwiftData

struct TrainingView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Workout.scheduledAt, order: .forward)
    private var workouts: [Workout]

    @State private var editing: Workout?
    @State private var showEditor = false

    private var calendar: Calendar { .current }

    private var todays: [Workout] {
        workouts.filter { $0.isToday }
    }

    private var upcoming: [Workout] {
        workouts.filter { !$0.isToday && !$0.isCompleted && $0.scheduledAt > .now }
    }

    private var recent: [Workout] {
        workouts
            .filter { $0.isCompleted && !$0.isToday }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        weekStrip

                        if workouts.isEmpty {
                            EmptyStateView(
                                systemImage: "dumbbell",
                                title: "No sessions planned",
                                message: "Add one with the plus button. A repeating session rebuilds itself each week once you complete it."
                            )
                            .vytrCard()
                        } else {
                            if !todays.isEmpty { todaySection }
                            if !upcoming.isEmpty { upcomingSection }
                            if !recent.isEmpty { historySection }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus").foregroundStyle(Theme.Palette.accent)
                    }
                }
            }
            .sheet(isPresented: $showEditor, onDismiss: syncNotifications) {
                WorkoutEditor(existing: editing)
            }
            .task { syncNotifications() }
        }
    }

    // MARK: - Week

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "This week")

            HStack(spacing: Theme.Spacing.s) {
                ForEach(weekDays, id: \.self) { day in
                    let sessions = workouts.filter { calendar.isDate($0.scheduledAt, inSameDayAs: day) }
                    let done = sessions.contains(where: \.isCompleted)
                    let planned = !sessions.isEmpty

                    VStack(spacing: Theme.Spacing.xs) {
                        Text(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1])
                            .font(.vytrLabel)
                            .foregroundStyle(Theme.Palette.textTertiary)

                        ZStack {
                            Circle()
                                .strokeBorder(
                                    planned ? Theme.Palette.accent : Theme.Palette.surfaceRaised,
                                    style: StrokeStyle(lineWidth: 2, dash: done ? [] : [3, 3])
                                )
                                .frame(width: 30, height: 30)

                            if done {
                                Circle()
                                    .fill(Theme.Palette.accent)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.Palette.background)
                            }
                        }

                        Circle()
                            .fill(calendar.isDateInToday(day) ? Theme.Palette.accent : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .vytrCard()
    }

    // MARK: - Sections

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Today")
            ForEach(todays) { workout in
                sessionCard(workout, expanded: true)
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "Coming up")
            VStack(spacing: 0) {
                ForEach(upcoming) { workout in
                    compactRow(workout)
                    if workout.id != upcoming.last?.id {
                        Divider().overlay(Theme.Palette.separator)
                    }
                }
            }
            .vytrCard()
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "Completed")
            VStack(spacing: 0) {
                ForEach(recent) { workout in
                    compactRow(workout)
                    if workout.id != recent.last?.id {
                        Divider().overlay(Theme.Palette.separator)
                    }
                }
            }
            .vytrCard()
        }
    }

    // MARK: - Cards

    private func sessionCard(_ workout: Workout, expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(.vytrBody.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(workout.timeText)
                        .font(.vytrCaption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                Button {
                    editing = workout
                    showEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }

            if expanded && !workout.exercises.isEmpty {
                VStack(spacing: 0) {
                    ForEach(workout.orderedExercises) { exercise in
                        exerciseRow(exercise)
                        if exercise.id != workout.orderedExercises.last?.id {
                            Divider().overlay(Theme.Palette.separator)
                        }
                    }
                }
            }

            VytrButton(
                title: workout.isCompleted ? "Completed" : "Mark as done",
                systemImage: workout.isCompleted ? "checkmark.circle.fill" : nil,
                kind: workout.isCompleted ? .secondary : .primary
            ) {
                toggleComplete(workout)
            }
        }
        .vytrCard()
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            withAnimation(Theme.Motion.spring) {
                exercise.isDone.toggle()
                try? context.save()
            }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: exercise.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(exercise.isDone ? Theme.Palette.accent : Theme.Palette.textTertiary)

                Text(exercise.name)
                    .font(.vytrBody)
                    .foregroundStyle(exercise.isDone ? Theme.Palette.textTertiary : Theme.Palette.textPrimary)
                    .strikethrough(exercise.isDone, color: Theme.Palette.textTertiary)

                Spacer(minLength: Theme.Spacing.s)

                Text("\(exercise.sets)x\(exercise.reps)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.vertical, Theme.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func compactRow(_ workout: Workout) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: workout.isCompleted ? "checkmark.circle.fill" : "calendar")
                .font(.system(size: 15))
                .foregroundStyle(workout.isCompleted ? Theme.Palette.accent : Theme.Palette.textTertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(workout.name)
                    .font(.vytrBody)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(workout.scheduledAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Spacer(minLength: 0)

            if !workout.exercises.isEmpty {
                Text("\(workout.doneCount)/\(workout.exercises.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .contentShape(Rectangle())
        .onTapGesture {
            editing = workout
            showEditor = true
        }
        .contextMenu {
            Button(role: .destructive) {
                context.delete(workout)
                try? context.save()
                syncNotifications()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func toggleComplete(_ workout: Workout) {
        withAnimation(Theme.Motion.spring) {
            if workout.isCompleted {
                workout.completedAt = nil
            } else {
                workout.completedAt = .now
                // A repeating session rebuilds itself here, so the plan
                // survives without a separate template to maintain.
                if let next = workout.nextWeekCopy() {
                    context.insert(next)
                }
            }
            try? context.save()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        syncNotifications()
    }

    private func syncNotifications() {
        let snapshot = workouts
        Task { await NotificationService.rescheduleWorkouts(snapshot) }
    }
}
