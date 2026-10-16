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

    /// Deleting a workout deletes its exercises with it.
    @Relationship(deleteRule: .cascade)
    var exercises: [Exercise]

    init(
        name: String,
        scheduledAt: Date,
        completedAt: Date? = nil,
        exercises: [Exercise] = []
    ) {
        self.name = name
        self.scheduledAt = scheduledAt
        self.completedAt = completedAt
        self.exercises = exercises
    }

    var isCompleted: Bool { completedAt != nil }

    var orderedExercises: [Exercise] {
        exercises.sorted { $0.order < $1.order }
    }
}
