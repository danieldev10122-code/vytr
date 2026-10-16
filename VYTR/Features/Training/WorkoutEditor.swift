import SwiftUI
import SwiftData

struct WorkoutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existing: Workout?

    @State private var name = ""
    @State private var date = Calendar.current.date(
        bySettingHour: 18, minute: 0, second: 0, of: .now
    ) ?? .now
    @State private var repeatsWeekly = true
    @State private var notifyMinutes = 30
    @State private var drafts: [ExerciseDraft] = []
    @State private var newExercise = ""

    /// Exercises are edited as plain values and only written to the store
    /// on save, so cancelling leaves nothing behind.
    struct ExerciseDraft: Identifiable {
        let id = UUID()
        var name: String
        var sets: Int = 3
        var reps: Int = 10
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedName.isEmpty }

    private let reminderOptions = [0, 15, 30, 60, 120]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        VStack(spacing: 0) {
                            FormField(label: "Session", placeholder: "Upper body", text: $name)
                        }
                        .vytrCard()

                        scheduleCard
                        exercisesCard
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationTitle(existing == nil ? "New session" : "Edit session")
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
            .onAppear(perform: load)
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "When")

            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.Palette.accent)

            Divider().overlay(Theme.Palette.separator)

            Toggle(isOn: $repeatsWeekly) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Repeat weekly")
                        .font(.vytrBody)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("Completing it schedules next week")
                        .font(.vytrCaption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .tint(Theme.Palette.accent)

            Divider().overlay(Theme.Palette.separator)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Remind me before")
                    .font(.vytrBody)
                    .foregroundStyle(Theme.Palette.textPrimary)

                HStack(spacing: Theme.Spacing.s) {
                    ForEach(reminderOptions, id: \.self) { minutes in
                        Button {
                            withAnimation(Theme.Motion.spring) { notifyMinutes = minutes }
                        } label: {
                            Text(minutes == 0 ? "Off" : "\(minutes)m")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(notifyMinutes == minutes
                                                 ? Theme.Palette.background
                                                 : Theme.Palette.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(notifyMinutes == minutes
                                                   ? Theme.Palette.accent
                                                   : Theme.Palette.surfaceRaised)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .vytrCard()
    }

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Exercises")

            if drafts.isEmpty {
                Text("No exercises yet. A session can be saved without them.")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            } else {
                VStack(spacing: 0) {
                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            HStack {
                                Text(draft.name)
                                    .font(.vytrBody)
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                    .lineLimit(1)

                                Spacer(minLength: Theme.Spacing.s)

                                Button {
                                    withAnimation(Theme.Motion.spring) {
                                        drafts.removeAll { $0.id == draft.id }
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }

                            HStack(spacing: Theme.Spacing.m) {
                                counter(label: "Sets", value: $draft.sets, range: 1...10)
                                counter(label: "Reps", value: $draft.reps, range: 1...50)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.s)

                        if draft.id != drafts.last?.id {
                            Divider().overlay(Theme.Palette.separator)
                        }
                    }
                }
            }

            HStack(spacing: Theme.Spacing.s) {
                TextField("Add an exercise", text: $newExercise)
                    .font(.vytrBody)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(Theme.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .fill(Theme.Palette.surfaceRaised)
                    )
                    .onSubmit(addExercise)

                Button(action: addExercise) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.background)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(
                            newExercise.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Theme.Palette.textTertiary
                            : Theme.Palette.accent
                        ))
                }
                .buttonStyle(.plain)
                .disabled(newExercise.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .vytrCard()
    }

    /// A minus/number/plus control, small enough that two fit on one line.
    private func counter(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(label)
                .font(.vytrLabel)
                .tracking(1)
                .foregroundStyle(Theme.Palette.textTertiary)

            Button {
                if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.Palette.surfaceRaised))
            }
            .buttonStyle(.plain)

            Text("\(value.wrappedValue)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(minWidth: 22)

            Button {
                if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Theme.Palette.surfaceRaised))
            }
            .buttonStyle(.plain)
        }
    }

    private func addExercise() {
        let trimmed = newExercise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(Theme.Motion.spring) {
            drafts.append(ExerciseDraft(name: trimmed))
            newExercise = ""
        }
    }

    private func load() {
        guard let existing else { return }
        name = existing.name
        date = existing.scheduledAt
        repeatsWeekly = existing.repeatsWeekly
        notifyMinutes = existing.notifyMinutesBefore
        drafts = existing.orderedExercises.map {
            ExerciseDraft(name: $0.name, sets: $0.sets, reps: $0.reps)
        }
    }

    private func save() {
        let exercises = drafts.enumerated().map { index, draft in
            Exercise(name: draft.name, sets: draft.sets, reps: draft.reps, order: index)
        }

        if let existing {
            existing.name = trimmedName
            existing.scheduledAt = date
            existing.repeatsWeekly = repeatsWeekly
            existing.notifyMinutesBefore = notifyMinutes
            // Replaced wholesale: the drafts are the intended list, and
            // matching them up one by one would only risk drift.
            for exercise in existing.exercises { context.delete(exercise) }
            existing.exercises = exercises
        } else {
            context.insert(
                Workout(
                    name: trimmedName,
                    scheduledAt: date,
                    repeatsWeekly: repeatsWeekly,
                    notifyMinutesBefore: notifyMinutes,
                    exercises: exercises
                )
            )
        }

        try? context.save()
        dismiss()
    }
}
