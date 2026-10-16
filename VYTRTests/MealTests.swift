import XCTest
@testable import VYTR

/// The calorie range is the one piece of logic the whole app leans on:
/// it is what keeps an estimate from being presented as a measurement.
final class MealTests: XCTestCase {

    func testManualEntryIsNotAnEstimate() {
        let meal = Meal(name: "Oats", caloriesMin: 420, caloriesMax: 420)

        XCTAssertFalse(meal.isEstimate)
        XCTAssertEqual(meal.caloriesDisplay, "420")
        XCTAssertEqual(meal.caloriesMidpoint, 420)
    }

    func testRangeIsAnEstimate() {
        let meal = Meal(name: "Burger", caloriesMin: 505, caloriesMax: 685)

        XCTAssertTrue(meal.isEstimate)
        XCTAssertEqual(meal.caloriesDisplay, "505-685")
        // The figure the Today ring shows, and the one that first
        // appeared on device as ~595.
        XCTAssertEqual(meal.caloriesMidpoint, 595)
    }

    func testBoundsAreNormalisedWhenPassedBackwards() {
        let meal = Meal(name: "Reversed", caloriesMin: 900, caloriesMax: 400)

        XCTAssertEqual(meal.caloriesMin, 400)
        XCTAssertEqual(meal.caloriesMax, 900)
        XCTAssertEqual(meal.caloriesMidpoint, 650)
    }

    func testUnknownMacrosStayNilRatherThanZero() {
        let meal = Meal(name: "Unknown", caloriesMin: 300, caloriesMax: 300)

        // A missing macro must not become a measured zero. The detail
        // screen prints "not recorded" for exactly this case.
        XCTAssertNil(meal.proteinGrams)
        XCTAssertNil(meal.carbsGrams)
        XCTAssertNil(meal.fatGrams)
    }

    func testSourceFallsBackWhenTheStoredValueIsUnknown() {
        let meal = Meal(name: "Legacy", caloriesMin: 100, caloriesMax: 100)
        meal.sourceRaw = "somethingAddedInAFutureVersion"

        // Stored as a raw string so an unrecognised value degrades
        // instead of breaking the store.
        XCTAssertEqual(meal.source, .manual)
    }

    func testPhotoEstimateSourceRoundTrips() {
        let meal = Meal(
            name: "From a photo",
            caloriesMin: 400,
            caloriesMax: 600,
            source: .photoEstimate
        )

        XCTAssertEqual(meal.source, .photoEstimate)
    }
}
