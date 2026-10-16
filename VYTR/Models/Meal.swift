import Foundation
import SwiftData

/// Where a meal's numbers came from. This is shown in the UI so an
/// estimate is never mistaken for something that was measured.
enum MealSource: String, Codable {
    case manual
    case photoEstimate
}

@Model
final class Meal {
    var name: String
    var eatenAt: Date

    /// Calories are stored as a range. A manual entry sets both bounds to
    /// the same number; a photo estimate keeps them apart, because an
    /// estimate from an image is not a measurement.
    var caloriesMin: Int
    var caloriesMax: Int

    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?

    /// Stored outside the database file so the store stays small.
    @Attribute(.externalStorage) var photo: Data?

    /// Raw value rather than the enum, so adding a case later cannot
    /// break an existing store.
    var sourceRaw: String

    init(
        name: String,
        eatenAt: Date = .now,
        caloriesMin: Int,
        caloriesMax: Int,
        proteinGrams: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil,
        photo: Data? = nil,
        source: MealSource = .manual
    ) {
        self.name = name
        self.eatenAt = eatenAt
        self.caloriesMin = min(caloriesMin, caloriesMax)
        self.caloriesMax = max(caloriesMin, caloriesMax)
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.photo = photo
        self.sourceRaw = source.rawValue
    }

    var source: MealSource {
        MealSource(rawValue: sourceRaw) ?? .manual
    }

    var isEstimate: Bool { caloriesMin != caloriesMax }

    /// Used when summing a day. The midpoint of a range, never presented
    /// on its own as if it were exact.
    var caloriesMidpoint: Int { (caloriesMin + caloriesMax) / 2 }

    /// "520" for a known value, "480-560" for an estimate.
    var caloriesDisplay: String {
        isEstimate ? "\(caloriesMin)-\(caloriesMax)" : "\(caloriesMin)"
    }
}
