import XCTest
@testable import VYTR

/// A repeating session rebuilds itself when completed. That is what keeps
/// the weekly plan alive without a separate template, so it is worth
/// pinning down.
final class WorkoutTests: XCTestCase {

    private func makeWorkout(
        repeats: Bool = true,
        notify: Int = 30,
        at date: Date = .now.addingTimeInterval(3600)
    ) -> Workout {
        Workout(
            name: "Upper body",
            scheduledAt: date,
            repeatsWeekly: repeats,
            notifyMinutesBefore: notify,
            exercises: [
                Exercise(name: "Bench press", sets: 4, reps: 8, isDone: true, order: 0),
                Exercise(name: "Row", sets: 3, reps: 12, isDone: true, order: 1)
            ]
        )
    }

    func testNonRepeatingSessionDoesNotRebuildItself() {
        XCTAssertNil(makeWorkout(repeats: false).nextWeekCopy())
    }

    func testNextCopyIsExactlyOneWeekLater() throws {
        let workout = makeWorkout()
        let copy = try XCTUnwrap(workout.nextWeekCopy())

        let days = Calendar.current.dateComponents(
            [.day], from: workout.scheduledAt, to: copy.scheduledAt
        ).day

        XCTAssertEqual(days, 7)
        XCTAssertEqual(copy.name, workout.name)
        XCTAssertTrue(copy.repeatsWeekly)
        XCTAssertEqual(copy.notifyMinutesBefore, workout.notifyMinutesBefore)
    }

    func testNextCopyCarriesTheExercisesButResetsProgress() throws {
        let copy = try XCTUnwrap(makeWorkout().nextWeekCopy())

        XCTAssertEqual(copy.exercises.count, 2)
        // Last week's ticks must not come along.
        XCTAssertTrue(copy.exercises.allSatisfy { !$0.isDone })

        let ordered = copy.orderedExercises
        XCTAssertEqual(ordered.map(\.name), ["Bench press", "Row"])
        XCTAssertEqual(ordered.map(\.sets), [4, 3])
        XCTAssertEqual(ordered.map(\.reps), [8, 12])
    }

    func testNextCopyIsNotMarkedComplete() throws {
        let workout = makeWorkout()
        workout.completedAt = .now
        let copy = try XCTUnwrap(workout.nextWeekCopy())

        XCTAssertFalse(copy.isCompleted)
        XCTAssertNil(copy.completedAt)
    }

    func testDoneCountTracksTickedExercises() {
        let workout = makeWorkout()
        XCTAssertEqual(workout.doneCount, 2)

        workout.exercises.forEach { $0.isDone = false }
        XCTAssertEqual(workout.doneCount, 0)
    }

    func testReminderIsOffWhenMinutesIsZero() {
        XCTAssertNil(makeWorkout(notify: 0).reminderDate)
    }

    func testCompletedSessionHasNoReminder() {
        let workout = makeWorkout()
        workout.completedAt = .now
        XCTAssertNil(workout.reminderDate)
    }

    func testReminderFiresTheChosenNumberOfMinutesEarlier() throws {
        let start = Date.now.addingTimeInterval(4 * 3600)
        let workout = makeWorkout(notify: 45, at: start)

        let fire = try XCTUnwrap(workout.reminderDate)
        XCTAssertEqual(start.timeIntervalSince(fire), 45 * 60, accuracy: 1)
    }

    func testReminderInThePastIsNotScheduled() {
        // Starts in ten minutes, wants a 30 minute warning: that moment
        // has already gone, so there is nothing to schedule.
        let workout = makeWorkout(notify: 30, at: .now.addingTimeInterval(600))
        XCTAssertNil(workout.reminderDate)
    }

    func testOrderedExercisesSortsByOrderNotInsertion() {
        let workout = Workout(
            name: "Mixed",
            scheduledAt: .now,
            exercises: [
                Exercise(name: "Third", order: 2),
                Exercise(name: "First", order: 0),
                Exercise(name: "Second", order: 1)
            ]
        )

        XCTAssertEqual(workout.orderedExercises.map(\.name), ["First", "Second", "Third"])
    }
}
