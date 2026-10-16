import XCTest
@testable import VYTR

/// Decoding the shape the response schema asks Gemini for. If the model
/// or the schema drifts, this is where it should be noticed rather than
/// on the phone with a photo already taken.
final class MealAnalysisTests: XCTestCase {

    private func decode(_ json: String) throws -> MealAnalysis {
        try JSONDecoder().decode(MealAnalysis.self, from: Data(json.utf8))
    }

    func testDecodesTheFullResponse() throws {
        let analysis = try decode("""
        {
          "mealName": "Chicken nugget sandwich",
          "confidence": "medium",
          "items": [
            {"name": "Chicken sandwich", "portion": "1 small bun", "caloriesMin": 320, "caloriesMax": 420},
            {"name": "Nuggets", "portion": "6 pieces", "caloriesMin": 185, "caloriesMax": 265}
          ],
          "totalCaloriesMin": 505,
          "totalCaloriesMax": 685,
          "proteinGrams": 24.0,
          "carbsGrams": 58.5,
          "fatGrams": 27.0,
          "notes": "Sauce quantity is unclear."
        }
        """)

        XCTAssertEqual(analysis.mealName, "Chicken nugget sandwich")
        XCTAssertEqual(analysis.confidence, .medium)
        XCTAssertEqual(analysis.confidence.label, "Rough estimate")
        XCTAssertEqual(analysis.items.count, 2)
        XCTAssertEqual(analysis.totalCaloriesMin, 505)
        XCTAssertEqual(analysis.totalCaloriesMax, 685)
        XCTAssertEqual(analysis.proteinGrams, 24.0)
        XCTAssertFalse(analysis.isEmpty)
        XCTAssertEqual(analysis.caloriesDisplay, "505-685")
    }

    func testDecodesAnEmptyResultWithoutOptionalFields() throws {
        // What the prompt asks for when no food can be identified, and
        // the macros and notes are absent entirely.
        let analysis = try decode("""
        {
          "mealName": "Not food",
          "confidence": "low",
          "items": [],
          "totalCaloriesMin": 0,
          "totalCaloriesMax": 0
        }
        """)

        XCTAssertTrue(analysis.isEmpty)
        XCTAssertEqual(analysis.confidence, .low)
        XCTAssertNil(analysis.proteinGrams)
        XCTAssertNil(analysis.notes)
        XCTAssertEqual(analysis.caloriesDisplay, "0")
    }

    func testEqualBoundsPrintAsOneFigure() throws {
        let analysis = try decode("""
        {
          "mealName": "Exact",
          "confidence": "high",
          "items": [{"name": "Apple", "portion": "1 medium", "caloriesMin": 95, "caloriesMax": 95}],
          "totalCaloriesMin": 95,
          "totalCaloriesMax": 95
        }
        """)

        XCTAssertEqual(analysis.caloriesDisplay, "95")
        XCTAssertEqual(analysis.confidence.label, "Good confidence")
    }

    func testUnknownConfidenceIsRejectedRatherThanGuessed() {
        // A value outside the schema should fail loudly here rather than
        // silently becoming "high" on screen.
        XCTAssertThrowsError(try decode("""
        {
          "mealName": "Odd",
          "confidence": "extremely-sure",
          "items": [],
          "totalCaloriesMin": 0,
          "totalCaloriesMax": 0
        }
        """))
    }

    func testMissingRequiredFieldFails() {
        XCTAssertThrowsError(try decode("""
        {"mealName": "No totals", "confidence": "low", "items": []}
        """))
    }
}
