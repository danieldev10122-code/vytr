import Foundation
import SwiftData

@Model
final class Exercise {
    var name: String
    var sets: Int
    var reps: Int
    var isDone: Bool
    /// Keeps a workout's exercises in the order they were entered.
    var order: Int

    init(name: String, sets: Int = 3, reps: Int = 10, isDone: Bool = false, order: Int = 0) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.isDone = isDone
        self.order = order
    }
}

@Model
final class Workout {
    var name: String
    var scheduledAt: Date
    var completedAt: Date?

    /// A workout is a dated session, not a template. Marking a repeating
    /// one complete creates next week's copy, so the plan maintains itself
    /// while every session that happened stays a real record with its own
    /// completion date.
    var repeatsWeekly: Bool

    /// Minutes before the session to be reminded. Zero means no reminder.
    var notifyMinutesBefore: Int

    /// Deleting a workout deletes its exercises with it.
    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise]

    init(
        name: String,
        scheduledAt: Date,
        completedAt: Date? = nil,
        repeatsWeekly: Bool = true,
        notifyMinutesBefore: Int = 30,
        exercises: [Exercise] = []
    ) {
        self.name = name
        self.scheduledAt = scheduledAt
        self.completedAt = completedAt
        self.repeatsWeekly = repeatsWeekly
        self.notifyMinutesBefore = notifyMinutesBefore
        self.exercises = exercises
    }

    var isCompleted: Bool { completedAt != nil }

    var orderedExercises: [Exercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var doneCount: Int {
        exercises.filter(\.isDone).count
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(scheduledAt)
    }

    var timeText: String {
        scheduledAt.formatted(date: .omitted, time: .shortened)
    }

    /// When to fire the pre-session reminder, if one is wanted and the
    /// session has not already happened.
    var reminderDate: Date? {
        guard notifyMinutesBefore > 0, !isCompleted else { return nil }
        let date = scheduledAt.addingTimeInterval(-Double(notifyMinutesBefore) * 60)
        return date > .now ? date : nil
    }

    /// The same session a week later, with its exercises reset. Called
    /// when a repeating workout is completed.
    func nextWeekCopy() -> Workout? {
        guard repeatsWeekly else { return nil }
        guard let next = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: scheduledAt) else {
            return nil
        }

        return Workout(
            name: name,
            scheduledAt: next,
            repeatsWeekly: true,
            notifyMinutesBefore: notifyMinutesBefore,
            exercises: orderedExercises.enumerated().map { index, exercise in
                Exercise(name: exercise.name, sets: exercise.sets, reps: exercise.reps, order: index)
            }
        )
    }
}
