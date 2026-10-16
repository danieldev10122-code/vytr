import Foundation
import SwiftData

/// Turns what is in the local store into a backup file, and merges a
/// backup file back in.
///
/// Import never deletes and never overwrites. It only adds the entries
/// the store does not already have, judged by the identity rule written
/// down in `BackupDocument`. Running the same import twice therefore
/// changes nothing the second time.
enum BackupService {

    /// What an import would do, worked out before anything is written so
    /// the user can be told first.
    struct Plan {
        let document: BackupDocument
        let photos: [String: Data]
        let newMeals: [BackupDocument.MealRecord]
        let newWorkouts: [BackupDocument.WorkoutRecord]
        let newReminders: [BackupDocument.ReminderRecord]

        var newCount: Int { newMeals.count + newWorkouts.count + newReminders.count }
        var alreadyPresentCount: Int { document.entryCount - newCount }
        var isEmpty: Bool { newCount == 0 }
    }

    // MARK: - Export

    static func makeDocument(context: ModelContext, now: Date = .now) throws -> (BackupDocument, [String: Data]) {
        let meals = try context.fetch(
            FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.eatenAt)])
        )
        let workouts = try context.fetch(
            FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.scheduledAt)])
        )
        let reminders = try context.fetch(
            FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.createdAt)])
        )

        var photos: [String: Data] = [:]
        var photoIndex = 0

        let mealRecords: [BackupDocument.MealRecord] = meals.map { meal in
            var path: String?
            if let data = meal.photo, !data.isEmpty {
                photoIndex += 1
                let name = String(format: "photos/%04d.jpg", photoIndex)
                photos[name] = data
                path = name
            }
            return BackupDocument.MealRecord(
                name: meal.name,
                eatenAt: meal.eatenAt.flooredToSecond,
                caloriesMin: meal.caloriesMin,
                caloriesMax: meal.caloriesMax,
                proteinGrams: meal.proteinGrams,
                carbsGrams: meal.carbsGrams,
                fatGrams: meal.fatGrams,
                source: meal.sourceRaw,
                photoPath: path
            )
        }

        let workoutRecords = workouts.map { workout in
            BackupDocument.WorkoutRecord(
                name: workout.name,
                scheduledAt: workout.scheduledAt.flooredToSecond,
                completedAt: workout.completedAt?.flooredToSecond,
                repeatsWeekly: workout.repeatsWeekly,
                notifyMinutesBefore: workout.notifyMinutesBefore,
                exercises: workout.orderedExercises.enumerated().map { index, exercise in
                    BackupDocument.ExerciseRecord(
                        name: exercise.name,
                        sets: exercise.sets,
                        reps: exercise.reps,
                        isDone: exercise.isDone,
                        order: index
                    )
                }
            )
        }

        let reminderRecords = reminders.map { reminder in
            BackupDocument.ReminderRecord(
                title: reminder.title,
                hour: reminder.hour,
                minute: reminder.minute,
                weekdayMask: reminder.weekdayMask,
                isEnabled: reminder.isEnabled,
                createdAt: reminder.createdAt.flooredToSecond
            )
        }

        let document = BackupDocument(
            exportedAt: now.flooredToSecond,
            appVersion: SigningInfo.version,
            meals: mealRecords,
            workouts: workoutRecords,
            reminders: reminderRecords
        )

        return (document, photos)
    }

    static func exportData(context: ModelContext, now: Date = .now) throws -> Data {
        let (document, photos) = try makeDocument(context: context, now: now)
        return try BackupFile.write(document, photos: photos)
    }

    /// Writes the backup where the share sheet can pick it up. A fresh
    /// folder each time, so an older file is never shared by mistake.
    static func exportFile(context: ModelContext, now: Date = .now) throws -> URL {
        let data = try exportData(context: context, now: now)

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("VYTRBackup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let url = folder.appendingPathComponent(fileName(for: now))
        try data.write(to: url, options: .atomic)
        return url
    }

    static func fileName(for date: Date) -> String {
        let stamp = date.formatted(
            .iso8601.year().month().day().dateSeparator(.dash)
        )
        return "VYTR-backup-\(stamp).\(BackupDocument.fileExtension)"
    }

    // MARK: - Import

    /// Reads a file and works out what it would add. Nothing is written.
    static func plan(forImporting data: Data, context: ModelContext) throws -> Plan {
        let (document, photos) = try BackupFile.read(data)

        let existingMeals = Set(
            try context.fetch(FetchDescriptor<Meal>()).map(identity(of:))
        )
        let existingWorkouts = Set(
            try context.fetch(FetchDescriptor<Workout>()).map(identity(of:))
        )
        let existingReminders = Set(
            try context.fetch(FetchDescriptor<Reminder>()).map(identity(of:))
        )

        // A file can hold two entries that are the same by this rule -
        // from a backup merged out of two devices, say. Keeping a seen
        // set means the import does not duplicate those either.
        var seen = Set<String>()

        let newMeals = document.meals.filter {
            !existingMeals.contains($0.identity) && seen.insert($0.identity).inserted
        }
        let newWorkouts = document.workouts.filter {
            !existingWorkouts.contains($0.identity) && seen.insert($0.identity).inserted
        }
        let newReminders = document.reminders.filter {
            !existingReminders.contains($0.identity) && seen.insert($0.identity).inserted
        }

        return Plan(
            document: document,
            photos: photos,
            newMeals: newMeals,
            newWorkouts: newWorkouts,
            newReminders: newReminders
        )
    }

    /// Inserts exactly what the plan listed. Existing rows are untouched.
    @discardableResult
    static func apply(_ plan: Plan, context: ModelContext) throws -> Int {
        for record in plan.newMeals {
            let meal = Meal(
                name: record.name,
                eatenAt: record.eatenAt,
                caloriesMin: record.caloriesMin,
                caloriesMax: record.caloriesMax,
                proteinGrams: record.proteinGrams,
                carbsGrams: record.carbsGrams,
                fatGrams: record.fatGrams,
                photo: record.photoPath.flatMap { plan.photos[$0] },
                source: MealSource(rawValue: record.source) ?? .manual
            )
            context.insert(meal)
        }

        for record in plan.newWorkouts {
            let workout = Workout(
                name: record.name,
                scheduledAt: record.scheduledAt,
                completedAt: record.completedAt,
                repeatsWeekly: record.repeatsWeekly,
                notifyMinutesBefore: record.notifyMinutesBefore,
                exercises: record.exercises
                    .sorted { $0.order < $1.order }
                    .enumerated()
                    .map { index, exercise in
                        Exercise(
                            name: exercise.name,
                            sets: exercise.sets,
                            reps: exercise.reps,
                            isDone: exercise.isDone,
                            order: index
                        )
                    }
            )
            context.insert(workout)
        }

        for record in plan.newReminders {
            let reminder = Reminder(
                title: record.title,
                hour: record.hour,
                minute: record.minute,
                weekdayMask: record.weekdayMask,
                isEnabled: record.isEnabled,
                createdAt: record.createdAt
            )
            context.insert(reminder)
        }

        try context.save()
        return plan.newCount
    }

    // MARK: - Identity of what is already stored

    static func identity(of meal: Meal) -> String {
        BackupIdentity.meal(
            name: meal.name,
            eatenAt: meal.eatenAt,
            caloriesMin: meal.caloriesMin,
            caloriesMax: meal.caloriesMax
        )
    }

    static func identity(of workout: Workout) -> String {
        BackupIdentity.workout(name: workout.name, scheduledAt: workout.scheduledAt)
    }

    static func identity(of reminder: Reminder) -> String {
        BackupIdentity.reminder(
            title: reminder.title,
            hour: reminder.hour,
            minute: reminder.minute,
            weekdayMask: reminder.weekdayMask
        )
    }
}
