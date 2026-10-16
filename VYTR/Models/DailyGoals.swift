import SwiftUI

/// Targets the user can change later from a settings screen. Stored in
/// UserDefaults rather than SwiftData because they are a handful of
/// scalars with no history.
///
/// These are a guide for building habits, not a prescription.
enum DailyGoals {
    static let caloriesKey = "goal.calories"
    static let proteinKey  = "goal.protein"
    static let carbsKey    = "goal.carbs"
    static let fatKey      = "goal.fat"

    static let defaultCalories = 2200
    static let defaultProtein  = 150.0
    static let defaultCarbs    = 220.0
    static let defaultFat      = 70.0
}
