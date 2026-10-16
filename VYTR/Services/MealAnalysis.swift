import Foundation

/// What the model is asked to return. Every number is an estimate from a
/// photograph, so calories are always a range and confidence is explicit.
struct MealAnalysis: Decodable {

    struct Item: Decodable, Identifiable {
        let name: String
        let portion: String
        let caloriesMin: Int
        let caloriesMax: Int

        var id: String { name + portion }
    }

    enum Confidence: String, Decodable {
        case high, medium, low

        var label: String {
            switch self {
            case .high:   return "Good confidence"
            case .medium: return "Rough estimate"
            case .low:    return "Low confidence"
            }
        }
    }

    let mealName: String
    let confidence: Confidence
    let items: [Item]
    let totalCaloriesMin: Int
    let totalCaloriesMax: Int
    let proteinGrams: Double?
    let carbsGrams: Double?
    let fatGrams: Double?
    let notes: String?

    var isEmpty: Bool { items.isEmpty }

    var caloriesDisplay: String {
        totalCaloriesMin == totalCaloriesMax
            ? "\(totalCaloriesMin)"
            : "\(totalCaloriesMin)-\(totalCaloriesMax)"
    }
}
