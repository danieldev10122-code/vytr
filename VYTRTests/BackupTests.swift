import XCTest
import SwiftData
@testable import VYTR

/// Backup is the one feature whose failure mode is losing data, so the
/// tests go after the two things that would cause that: a file that does
/// not survive the round trip, and an import that duplicates or
/// overwrites what is already on the phone.
final class BackupTests: XCTestCase {

    // MARK: - Helpers

    /// An empty store that lives only for the length of one test.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Meal.self, Workout.self, Reminder.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func populate(_ context: ModelContext) throws {
        let breakfast = Meal(
            name: "Oats",
            eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
            caloriesMin: 420,
            caloriesMax: 420,
            proteinGrams: 18,
            photo: Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5])
        )
        let lunch = Meal(
            name: "Burger",
            eatenAt: Date(timeIntervalSince1970: 1_700_020_000),
            caloriesMin: 505,
            caloriesMax: 685,
            source: .photoEstimate
        )
        let workout = Workout(
            name: "Push",
            scheduledAt: Date(timeIntervalSince1970: 1_700_030_000),
            repeatsWeekly: true,
            notifyMinutesBefore: 30,
            exercises: [
                Exercise(name: "Bench", sets: 4, reps: 8, order: 0),
                Exercise(name: "Dips", sets: 3, reps: 12, isDone: true, order: 1)
            ]
        )
        let reminder = Reminder(
            title: "Log dinner",
            hour: 19,
            minute: 30,
            weekdayMask: Reminder.everyDay,
            createdAt: Date(timeIntervalSince1970: 1_699_000_000)
        )

        context.insert(breakfast)
        context.insert(lunch)
        context.insert(workout)
        context.insert(reminder)
        try context.save()
    }

    private func counts(_ context: ModelContext) throws -> (meals: Int, workouts: Int, reminders: Int) {
        (
            try context.fetchCount(FetchDescriptor<Meal>()),
            try context.fetchCount(FetchDescriptor<Workout>()),
            try context.fetchCount(FetchDescriptor<Reminder>())
        )
    }

    // MARK: - The container

    func testZipRoundTripsEveryEntryByteForByte() throws {
        let photo = Data((0..<5_000).map { UInt8($0 % 251) })
        let archive = ZipArchive.write([
            ZipArchive.Entry(name: "manifest.json", data: Data(#"{"a":1}"#.utf8)),
            ZipArchive.Entry(name: "photos/0001.jpg", data: photo)
        ])

        let read = try ZipArchive.read(archive)

        XCTAssertEqual(read.count, 2)
        XCTAssertEqual(read["manifest.json"], Data(#"{"a":1}"#.utf8))
        XCTAssertEqual(read["photos/0001.jpg"], photo)
    }

    /// The published CRC-32 check value, so the checksum that guards
    /// every entry is verified against the standard rather than itself.
    func testCRC32MatchesTheKnownValue() {
        XCTAssertEqual(ZipArchive.crc32(Data("123456789".utf8)), 0xCBF43926)
    }

    // MARK: - Round trip through the file

    func testExportThenImportRestoresEverythingIntoAnEmptyStore() throws {
        let source = try makeContext()
        try populate(source)

        let data = try BackupService.exportData(context: source)

        let restored = try makeContext()
        let plan = try BackupService.plan(forImporting: data, context: restored)
        XCTAssertEqual(plan.newCount, 4)
        try BackupService.apply(plan, context: restored)

        let after = try counts(restored)
        XCTAssertEqual(after.meals, 2)
        XCTAssertEqual(after.workouts, 1)
        XCTAssertEqual(after.reminders, 1)

        let meals = try restored.fetch(
            FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.eatenAt)])
        )
        XCTAssertEqual(meals[0].name, "Oats")
        XCTAssertEqual(meals[0].proteinGrams, 18)
        XCTAssertNil(meals[0].carbsGrams, "A macro that was never recorded must not come back as zero")
        XCTAssertEqual(meals[0].photo, Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5]), "The photo must survive byte for byte")
        XCTAssertEqual(meals[1].caloriesDisplay, "505-685")
        XCTAssertEqual(meals[1].source, .photoEstimate, "An estimate must not come back looking like a measurement")

        let workout = try XCTUnwrap(try restored.fetch(FetchDescriptor<Workout>()).first)
        XCTAssertEqual(workout.name, "Push")
        XCTAssertTrue(workout.repeatsWeekly)
        XCTAssertEqual(workout.notifyMinutesBefore, 30)
        XCTAssertEqual(workout.orderedExercises.map(\.name), ["Bench", "Dips"])
        XCTAssertEqual(workout.orderedExercises[1].sets, 3)
        XCTAssertTrue(workout.orderedExercises[1].isDone)

        let reminder = try XCTUnwrap(try restored.fetch(FetchDescriptor<Reminder>()).first)
        XCTAssertEqual(reminder.title, "Log dinner")
        XCTAssertEqual(reminder.hour, 19)
        XCTAssertEqual(reminder.minute, 30)
        XCTAssertEqual(reminder.weekdayMask, Reminder.everyDay)
    }

    // MARK: - Merging

    func testImportingIntoTheStoreItCameFromAddsNothing() throws {
        let context = try makeContext()
        try populate(context)
        let data = try BackupService.exportData(context: context)

        let plan = try BackupService.plan(forImporting: data, context: context)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.alreadyPresentCount, 4)

        try BackupService.apply(plan, context: context)
        let after = try counts(context)
        XCTAssertEqual(after.meals, 2)
        XCTAssertEqual(after.workouts, 1)
        XCTAssertEqual(after.reminders, 1)
    }

    func testImportingTwiceDoesNotDuplicate() throws {
        let source = try makeContext()
        try populate(source)
        let data = try BackupService.exportData(context: source)

        let target = try makeContext()
        try BackupService.apply(
            try BackupService.plan(forImporting: data, context: target),
            context: target
        )
        try BackupService.apply(
            try BackupService.plan(forImporting: data, context: target),
            context: target
        )

        let after = try counts(target)
        XCTAssertEqual(after.meals, 2)
        XCTAssertEqual(after.workouts, 1)
        XCTAssertEqual(after.reminders, 1)
    }

    func testOnlyTheMissingEntriesAreAdded() throws {
        let source = try makeContext()
        try populate(source)
        let data = try BackupService.exportData(context: source)

        // A phone that kept one of the meals but lost the rest.
        let target = try makeContext()
        target.insert(
            Meal(
                name: "Oats",
                eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
                caloriesMin: 420,
                caloriesMax: 420
            )
        )
        try target.save()

        let plan = try BackupService.plan(forImporting: data, context: target)
        XCTAssertEqual(plan.newMeals.count, 1)
        XCTAssertEqual(plan.newWorkouts.count, 1)
        XCTAssertEqual(plan.newReminders.count, 1)
        XCTAssertEqual(plan.alreadyPresentCount, 1)

        try BackupService.apply(plan, context: target)
        let after = try counts(target)
        XCTAssertEqual(after.meals, 2, "The kept meal must not be duplicated")
        XCTAssertEqual(after.workouts, 1)
        XCTAssertEqual(after.reminders, 1)
    }

    func testImportNeverChangesAnEntryThatIsAlreadyThere() throws {
        let source = try makeContext()
        let original = Meal(
            name: "Oats",
            eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
            caloriesMin: 420,
            caloriesMax: 420,
            proteinGrams: 18
        )
        source.insert(original)
        try source.save()
        let data = try BackupService.exportData(context: source)

        // Same identity, different macros: the local edit must win,
        // because import adds and never overwrites.
        let target = try makeContext()
        target.insert(
            Meal(
                name: "Oats",
                eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
                caloriesMin: 420,
                caloriesMax: 420,
                proteinGrams: 99
            )
        )
        try target.save()

        try BackupService.apply(
            try BackupService.plan(forImporting: data, context: target),
            context: target
        )

        let meals = try target.fetch(FetchDescriptor<Meal>())
        XCTAssertEqual(meals.count, 1)
        XCTAssertEqual(meals[0].proteinGrams, 99)
    }

    func testMealsThatDifferInCaloriesAreTreatedAsDifferentMeals() throws {
        let source = try makeContext()
        source.insert(
            Meal(
                name: "Oats",
                eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
                caloriesMin: 500,
                caloriesMax: 500
            )
        )
        try source.save()
        let data = try BackupService.exportData(context: source)

        let target = try makeContext()
        target.insert(
            Meal(
                name: "Oats",
                eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
                caloriesMin: 420,
                caloriesMax: 420
            )
        )
        try target.save()

        let plan = try BackupService.plan(forImporting: data, context: target)
        XCTAssertEqual(plan.newMeals.count, 1)
    }

    /// Sub-second differences would otherwise make the same meal look new
    /// on every import, because the file stores whole seconds.
    func testIdentityIgnoresFractionsOfASecond() throws {
        let source = try makeContext()
        source.insert(
            Meal(
                name: "Oats",
                eatenAt: Date(timeIntervalSince1970: 1_700_000_000.734),
                caloriesMin: 420,
                caloriesMax: 420
            )
        )
        try source.save()
        let data = try BackupService.exportData(context: source)

        let plan = try BackupService.plan(forImporting: data, context: source)
        XCTAssertTrue(plan.isEmpty)
    }

    func testEntriesRepeatedInsideOneFileAreAddedOnce() throws {
        let record = BackupDocument.MealRecord(
            name: "Oats",
            eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
            caloriesMin: 420,
            caloriesMax: 420,
            proteinGrams: nil,
            carbsGrams: nil,
            fatGrams: nil,
            source: MealSource.manual.rawValue,
            photoPath: nil
        )
        let document = BackupDocument(
            exportedAt: Date(timeIntervalSince1970: 1_700_100_000),
            appVersion: "test",
            meals: [record, record],
            workouts: [],
            reminders: []
        )
        let data = try BackupFile.write(document, photos: [:])

        let context = try makeContext()
        let plan = try BackupService.plan(forImporting: data, context: context)
        XCTAssertEqual(plan.newMeals.count, 1)

        try BackupService.apply(plan, context: context)
        XCTAssertEqual(try counts(context).meals, 1)
    }

    // MARK: - Files that are not good files

    func testRandomBytesAreRejectedRatherThanCrashing() throws {
        let context = try makeContext()
        let junk = Data((0..<2_048).map { _ in UInt8.random(in: 0...255) })

        XCTAssertThrowsError(try BackupService.plan(forImporting: junk, context: context)) { error in
            XCTAssertFalse(
                (error as NSError).localizedDescription.isEmpty,
                "A bad file has to produce something the user can read"
            )
        }
    }

    func testEmptyFileIsRejected() throws {
        let context = try makeContext()
        XCTAssertThrowsError(try BackupService.plan(forImporting: Data(), context: context))
    }

    func testTruncatedBackupIsReportedAsIncomplete() throws {
        let source = try makeContext()
        try populate(source)
        let data = try BackupService.exportData(context: source)
        let cut = data.prefix(data.count / 2)

        let context = try makeContext()
        XCTAssertThrowsError(try BackupService.plan(forImporting: Data(cut), context: context)) { error in
            XCTAssertTrue(
                error is ZipArchive.ZipError,
                "Expected a container error, got \(error)"
            )
        }
    }

    func testADamagedPhotoIsCaughtByItsChecksum() throws {
        let source = try makeContext()
        try populate(source)
        var data = try BackupService.exportData(context: source)

        // Flip a byte somewhere in the middle of the file. Without the
        // CRC check this would import silently as a broken photo.
        let index = data.index(data.startIndex, offsetBy: data.count / 2)
        data[index] = data[index] &+ 1

        let context = try makeContext()
        XCTAssertThrowsError(try BackupService.plan(forImporting: data, context: context))
    }

    func testAZipThatIsNotAVytrBackupIsRejected() throws {
        let archive = ZipArchive.write([
            ZipArchive.Entry(name: "notes.txt", data: Data("hello".utf8))
        ])

        let context = try makeContext()
        XCTAssertThrowsError(try BackupService.plan(forImporting: archive, context: context)) { error in
            guard case BackupFile.BackupFileError.missingManifest = error else {
                return XCTFail("Expected a missing manifest, got \(error)")
            }
        }
    }

    func testAManifestFromAnotherAppIsRejected() throws {
        let manifest = Data(#"{"format":"something.else","version":1,"exportedAt":"2026-01-01T00:00:00Z","appVersion":"x","meals":[],"workouts":[],"reminders":[]}"#.utf8)
        let archive = ZipArchive.write([
            ZipArchive.Entry(name: "manifest.json", data: manifest)
        ])

        let context = try makeContext()
        XCTAssertThrowsError(try BackupService.plan(forImporting: archive, context: context)) { error in
            guard case BackupFile.BackupFileError.notAVytrBackup = error else {
                return XCTFail("Expected a format mismatch, got \(error)")
            }
        }
    }

    func testAManifestFromANewerVersionIsRejectedRatherThanGuessedAt() throws {
        let manifest = Data(#"{"format":"vytr.backup","version":99,"exportedAt":"2026-01-01T00:00:00Z","appVersion":"x","meals":[],"workouts":[],"reminders":[]}"#.utf8)
        let archive = ZipArchive.write([
            ZipArchive.Entry(name: "manifest.json", data: manifest)
        ])

        let context = try makeContext()
        XCTAssertThrowsError(try BackupService.plan(forImporting: archive, context: context)) { error in
            guard case BackupFile.BackupFileError.newerFormat = error else {
                return XCTFail("Expected a version refusal, got \(error)")
            }
        }
    }

    func testCorruptJsonInsideAValidZipIsReportedClearly() throws {
        let archive = ZipArchive.write([
            ZipArchive.Entry(name: "manifest.json", data: Data("{ this is not json".utf8))
        ])

        let context = try makeContext()
        XCTAssertThrowsError(try BackupService.plan(forImporting: archive, context: context)) { error in
            guard case BackupFile.BackupFileError.unreadableManifest = error else {
                return XCTFail("Expected an unreadable manifest, got \(error)")
            }
        }
    }

    func testAMealWhosePhotoIsMissingFromTheZipIsRejected() throws {
        let document = BackupDocument(
            exportedAt: Date(timeIntervalSince1970: 1_700_100_000),
            appVersion: "test",
            meals: [
                BackupDocument.MealRecord(
                    name: "Oats",
                    eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
                    caloriesMin: 420,
                    caloriesMax: 420,
                    proteinGrams: nil,
                    carbsGrams: nil,
                    fatGrams: nil,
                    source: MealSource.manual.rawValue,
                    photoPath: "photos/0001.jpg"
                )
            ],
            workouts: [],
            reminders: []
        )
        // Written without the photo it points at.
        let archive = try BackupFile.write(document, photos: [:])

        let context = try makeContext()
        XCTAssertThrowsError(try BackupService.plan(forImporting: archive, context: context)) { error in
            guard case BackupFile.BackupFileError.missingPhoto = error else {
                return XCTFail("Expected a missing photo, got \(error)")
            }
        }
    }

    // MARK: - Nothing is ever removed

    func testImportLeavesEntriesTheBackupDoesNotMention() throws {
        let source = try makeContext()
        source.insert(
            Meal(
                name: "Oats",
                eatenAt: Date(timeIntervalSince1970: 1_700_000_000),
                caloriesMin: 420,
                caloriesMax: 420
            )
        )
        try source.save()
        let data = try BackupService.exportData(context: source)

        let target = try makeContext()
        target.insert(
            Meal(
                name: "Something logged after the backup",
                eatenAt: Date(timeIntervalSince1970: 1_800_000_000),
                caloriesMin: 300,
                caloriesMax: 300
            )
        )
        try target.save()

        try BackupService.apply(
            try BackupService.plan(forImporting: data, context: target),
            context: target
        )

        let names = try target.fetch(FetchDescriptor<Meal>()).map(\.name).sorted()
        XCTAssertEqual(names, ["Oats", "Something logged after the backup"])
    }

    func testEmptyStoreExportsAReadableFile() throws {
        let context = try makeContext()
        let data = try BackupService.exportData(context: context)

        let plan = try BackupService.plan(forImporting: data, context: context)
        XCTAssertEqual(plan.document.entryCount, 0)
        XCTAssertTrue(plan.isEmpty)
    }

    // MARK: - At volume

    /// The single test that stands in for a real journal: a store with
    /// enough variety in it that a field quietly dropped, a photo
    /// truncated, or an exercise reordered has somewhere to hide.
    func testBulkRoundTripReturnsEveryFieldUnchanged() throws {
        let source = try makeContext()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        // 20 meals: estimates with a range and manual entries with equal
        // bounds, photos on every third one, and macros left nil on some
        // so the nil-versus-zero distinction is covered at volume.
        for i in 0..<20 {
            let isEstimate = i % 2 == 1
            let meal = Meal(
                name: "Meal \(i)",
                eatenAt: start.addingTimeInterval(Double(i) * 3_600),
                caloriesMin: isEstimate ? 300 + i * 10 : 500 + i,
                caloriesMax: isEstimate ? 420 + i * 10 : 500 + i,
                proteinGrams: i % 3 == 0 ? nil : Double(20 + i),
                carbsGrams: i % 4 == 0 ? nil : Double(50 + i),
                fatGrams: i % 5 == 0 ? nil : Double(10 + i),
                photo: i % 3 == 0
                    ? Data((0..<(512 + i * 37)).map { UInt8(($0 &+ i) % 256) })
                    : nil,
                source: isEstimate ? .photoEstimate : .manual
            )
            source.insert(meal)
        }

        for w in 0..<3 {
            let workout = Workout(
                name: "Session \(w)",
                scheduledAt: start.addingTimeInterval(Double(w) * 86_400),
                completedAt: w == 0 ? start.addingTimeInterval(3_000) : nil,
                repeatsWeekly: w != 1,
                notifyMinutesBefore: w * 15,
                exercises: (0..<(w + 3)).map { e in
                    Exercise(
                        name: "Lift \(w)-\(e)",
                        sets: 3 + e,
                        reps: 8 + w,
                        isDone: e % 2 == 0,
                        order: e
                    )
                }
            )
            source.insert(workout)
        }

        for r in 0..<5 {
            source.insert(
                Reminder(
                    title: "Reminder \(r)",
                    hour: 7 + r,
                    minute: r * 11,
                    weekdayMask: r == 0 ? Reminder.everyDay : (1 << r),
                    isEnabled: r != 2,
                    createdAt: start.addingTimeInterval(Double(-r) * 600)
                )
            )
        }
        try source.save()

        let data = try BackupService.exportData(context: source)

        let restored = try makeContext()
        let plan = try BackupService.plan(forImporting: data, context: restored)
        XCTAssertEqual(plan.newCount, 28)
        try BackupService.apply(plan, context: restored)

        let before = try source.fetch(
            FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.eatenAt)])
        )
        let after = try restored.fetch(
            FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.eatenAt)])
        )
        XCTAssertEqual(after.count, 20)

        for (original, copy) in zip(before, after) {
            XCTAssertEqual(copy.name, original.name)
            XCTAssertEqual(copy.eatenAt, original.eatenAt)
            XCTAssertEqual(copy.caloriesMin, original.caloriesMin, original.name)
            XCTAssertEqual(copy.caloriesMax, original.caloriesMax, original.name)
            XCTAssertEqual(copy.proteinGrams, original.proteinGrams, original.name)
            XCTAssertEqual(copy.carbsGrams, original.carbsGrams, original.name)
            XCTAssertEqual(copy.fatGrams, original.fatGrams, original.name)
            XCTAssertEqual(copy.source, original.source, original.name)
            XCTAssertEqual(copy.isEstimate, original.isEstimate, original.name)
            XCTAssertEqual(copy.photo, original.photo, "Photo bytes differ for \(original.name)")
        }

        XCTAssertEqual(
            after.compactMap(\.photo).count, 7,
            "The meals that had photos must still have them"
        )
        XCTAssertTrue(
            after.contains { $0.proteinGrams == nil },
            "A macro that was never recorded must still be missing, not zero"
        )

        let workoutsBefore = try source.fetch(
            FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.scheduledAt)])
        )
        let workoutsAfter = try restored.fetch(
            FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.scheduledAt)])
        )
        XCTAssertEqual(workoutsAfter.count, 3)

        for (original, copy) in zip(workoutsBefore, workoutsAfter) {
            XCTAssertEqual(copy.name, original.name)
            XCTAssertEqual(copy.scheduledAt, original.scheduledAt)
            XCTAssertEqual(copy.completedAt, original.completedAt, original.name)
            XCTAssertEqual(copy.repeatsWeekly, original.repeatsWeekly, original.name)
            XCTAssertEqual(copy.notifyMinutesBefore, original.notifyMinutesBefore, original.name)

            let originalExercises = original.orderedExercises
            let copiedExercises = copy.orderedExercises
            XCTAssertEqual(copiedExercises.count, originalExercises.count, original.name)

            for (index, pair) in zip(originalExercises, copiedExercises).enumerated() {
                XCTAssertEqual(pair.1.name, pair.0.name, "Exercise \(index) of \(original.name)")
                XCTAssertEqual(pair.1.sets, pair.0.sets, pair.0.name)
                XCTAssertEqual(pair.1.reps, pair.0.reps, pair.0.name)
                XCTAssertEqual(pair.1.isDone, pair.0.isDone, pair.0.name)
                XCTAssertEqual(pair.1.order, index, "Exercises must come back in the order they were in")
            }
        }

        let remindersBefore = try source.fetch(
            FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.createdAt)])
        )
        let remindersAfter = try restored.fetch(
            FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.createdAt)])
        )
        XCTAssertEqual(remindersAfter.count, 5)

        for (original, copy) in zip(remindersBefore, remindersAfter) {
            XCTAssertEqual(copy.title, original.title)
            XCTAssertEqual(copy.hour, original.hour, original.title)
            XCTAssertEqual(copy.minute, original.minute, original.title)
            XCTAssertEqual(copy.weekdayMask, original.weekdayMask, original.title)
            XCTAssertEqual(copy.isEnabled, original.isEnabled, original.title)
            XCTAssertEqual(copy.createdAt, original.createdAt, original.title)
        }

        // And the whole lot again changes nothing.
        let second = try BackupService.plan(forImporting: data, context: restored)
        XCTAssertTrue(second.isEmpty)
    }

    func testFileNameCarriesTheDate() {
        let name = BackupService.fileName(for: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(name.hasPrefix("VYTR-backup-"), name)
        XCTAssertTrue(name.hasSuffix(".zip"), name)
    }
}
