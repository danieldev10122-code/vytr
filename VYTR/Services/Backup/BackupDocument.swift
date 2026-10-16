import Foundation

/// The contents of a VYTR backup, independent of SwiftData.
///
/// ## The file
///
/// A backup is a zip named `VYTR-backup-<date>.zip` holding:
///
/// - `manifest.json` - every meal, workout and reminder as plain JSON
/// - `photos/0001.jpg`, `0002.jpg`, ... - the meal photos, byte for byte
///
/// Photos are the reason this is not a single JSON file. Keeping them as
/// real JPEGs beside the manifest, rather than base64 inside it, means the
/// file can be opened on any computer and the pictures simply looked at.
///
/// ## How an entry is recognised again (identity)
///
/// The models have no id of their own, and adding one would be a schema
/// migration that risks the meals already on the phone. So identity is
/// derived from the content instead:
///
/// - a **meal** is the same meal when its name, the second it was eaten,
///   and both calorie bounds match
/// - a **workout** is the same session when its name and the second it is
///   scheduled for match. Its exercises travel with it and are never
///   merged separately
/// - a **reminder** is the same reminder when its title, hour, minute and
///   chosen days match
///
/// Names are compared trimmed and case-insensitively; times are compared
/// to the whole second, which is also the resolution the file stores. Two
/// meals that genuinely differ in any of those fields are two meals, so
/// the worst case of this rule is a duplicate that is easy to spot and
/// delete, never a lost or overwritten entry.
struct BackupDocument: Codable, Equatable {

    static let formatName = "vytr.backup"
    static let currentVersion = 1
    static let manifestEntry = "manifest.json"
    /// Plain `.zip`, deliberately: a backup nobody can open is not much
    /// of a backup. iOS, macOS and Windows all open it, and what makes it
    /// a VYTR backup is the manifest inside, which import checks.
    static let fileExtension = "zip"

    var format: String = BackupDocument.formatName
    var version: Int = BackupDocument.currentVersion
    var exportedAt: Date
    var appVersion: String

    var meals: [MealRecord]
    var workouts: [WorkoutRecord]
    var reminders: [ReminderRecord]

    // MARK: - Records

    struct MealRecord: Codable, Equatable {
        var name: String
        var eatenAt: Date
        var caloriesMin: Int
        var caloriesMax: Int
        var proteinGrams: Double?
        var carbsGrams: Double?
        var fatGrams: Double?
        var source: String
        /// Path of the photo inside the zip, when the meal has one.
        var photoPath: String?

        var identity: String {
            BackupIdentity.meal(
                name: name,
                eatenAt: eatenAt,
                caloriesMin: caloriesMin,
                caloriesMax: caloriesMax
            )
        }
    }

    struct ExerciseRecord: Codable, Equatable {
        var name: String
        var sets: Int
        var reps: Int
        var isDone: Bool
        var order: Int
    }

    struct WorkoutRecord: Codable, Equatable {
        var name: String
        var scheduledAt: Date
        var completedAt: Date?
        var repeatsWeekly: Bool
        var notifyMinutesBefore: Int
        var exercises: [ExerciseRecord]

        var identity: String {
            BackupIdentity.workout(name: name, scheduledAt: scheduledAt)
        }
    }

    struct ReminderRecord: Codable, Equatable {
        var title: String
        var hour: Int
        var minute: Int
        var weekdayMask: Int
        var isEnabled: Bool
        var createdAt: Date

        var identity: String {
            BackupIdentity.reminder(
                title: title,
                hour: hour,
                minute: minute,
                weekdayMask: weekdayMask
            )
        }
    }

    var entryCount: Int { meals.count + workouts.count + reminders.count }
}

// MARK: - Identity

/// One place where an entry's fingerprint is defined, so the rule used
/// when reading a file is the same one used against what is already in
/// the store.
enum BackupIdentity {

    static func meal(name: String, eatenAt: Date, caloriesMin: Int, caloriesMax: Int) -> String {
        "meal|\(key(name))|\(second(eatenAt))|\(caloriesMin)|\(caloriesMax)"
    }

    static func workout(name: String, scheduledAt: Date) -> String {
        "workout|\(key(name))|\(second(scheduledAt))"
    }

    static func reminder(title: String, hour: Int, minute: Int, weekdayMask: Int) -> String {
        "reminder|\(key(title))|\(hour)|\(minute)|\(weekdayMask)"
    }

    private static func key(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Whole seconds since 1970. Dates are written to the file at this
    /// resolution, so comparing at it keeps a re-imported backup from
    /// looking like a new entry.
    static func second(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970.rounded(.down))
    }
}

extension Date {
    /// Drops anything finer than a second, matching what the file stores.
    var flooredToSecond: Date {
        Date(timeIntervalSince1970: Double(BackupIdentity.second(self)))
    }
}

// MARK: - Reading and writing the file

enum BackupFile {

    enum BackupFileError: LocalizedError {
        case missingManifest
        case unreadableManifest(String)
        case notAVytrBackup(String)
        case newerFormat(Int)
        case missingPhoto(String)

        var errorDescription: String? {
            switch self {
            case .missingManifest:
                return "This zip has no manifest.json, so it is not a VYTR backup."
            case .unreadableManifest(let detail):
                return "The backup's manifest could not be read: \(detail)"
            case .notAVytrBackup(let format):
                return "This file says it is \"\(format)\", not a VYTR backup."
            case .newerFormat(let version):
                return "This backup was written by a newer version of VYTR (format \(version)). Update the app first."
            case .missingPhoto(let path):
                return "The backup refers to a photo that is not inside it (\(path))."
            }
        }
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Packs a document plus its photos into the archive bytes. Photo
    /// paths in the document must match the keys of `photos`.
    static func write(_ document: BackupDocument, photos: [String: Data]) throws -> Data {
        let manifest = try encoder().encode(document)
        var entries = [ZipArchive.Entry(name: BackupDocument.manifestEntry, data: manifest)]
        for path in photos.keys.sorted() {
            entries.append(ZipArchive.Entry(name: path, data: photos[path] ?? Data()))
        }
        return ZipArchive.write(entries)
    }

    /// Unpacks and validates archive bytes. Throws, rather than returning
    /// something half-formed, on anything that is not a readable backup.
    static func read(_ data: Data) throws -> (document: BackupDocument, photos: [String: Data]) {
        let entries = try ZipArchive.read(data)
        guard let manifest = entries[BackupDocument.manifestEntry] else {
            throw BackupFileError.missingManifest
        }

        let document: BackupDocument
        do {
            document = try decoder().decode(BackupDocument.self, from: manifest)
        } catch let error as DecodingError {
            throw BackupFileError.unreadableManifest(describe(error))
        }

        guard document.format == BackupDocument.formatName else {
            throw BackupFileError.notAVytrBackup(document.format)
        }
        guard document.version <= BackupDocument.currentVersion else {
            throw BackupFileError.newerFormat(document.version)
        }

        var photos: [String: Data] = [:]
        for meal in document.meals {
            guard let path = meal.photoPath else { continue }
            guard let photo = entries[path] else {
                throw BackupFileError.missingPhoto(path)
            }
            photos[path] = photo
        }

        return (document, photos)
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "a required field is missing (\(key.stringValue))"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? "a field has the wrong type" : "the field \(path) has the wrong type"
        case .dataCorrupted:
            return "it is not valid JSON"
        @unknown default:
            return "it could not be decoded"
        }
    }
}
