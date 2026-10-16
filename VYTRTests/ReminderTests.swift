import XCTest
@testable import VYTR

final class ReminderTests: XCTestCase {

    private func makeReminder(mask: Int, hour: Int = 18, minute: Int = 30) -> Reminder {
        Reminder(title: "Gym", hour: hour, minute: minute, weekdayMask: mask)
    }

    func testEveryDayCoversAllSevenWeekdays() {
        let reminder = makeReminder(mask: Reminder.everyDay)

        XCTAssertEqual(reminder.weekdays, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(reminder.daysText, "Every day")
    }

    func testWeekdayMaskMapsToCalendarNumbers() {
        // Bit 0 is Sunday, so Monday/Wednesday/Friday is bits 1, 3 and 5.
        let mask = (1 << 1) | (1 << 3) | (1 << 5)
        let reminder = makeReminder(mask: mask)

        XCTAssertEqual(reminder.weekdays, [2, 4, 6])
    }

    func testWeekdaysAndWeekendsGetShortNames() {
        let weekdays = makeReminder(mask: (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5))
        XCTAssertEqual(weekdays.daysText, "Weekdays")

        let weekends = makeReminder(mask: (1 << 0) | (1 << 6))
        XCTAssertEqual(weekends.daysText, "Weekends")
    }

    func testNoDaysSelectedIsStatedRatherThanBlank() {
        XCTAssertEqual(makeReminder(mask: 0).daysText, "No days selected")
        XCTAssertTrue(makeReminder(mask: 0).weekdays.isEmpty)
    }

    func testNextOccurrenceIsInTheFutureAndMatchesTheChosenTime() throws {
        let reminder = makeReminder(mask: Reminder.everyDay, hour: 7, minute: 15)

        let next = try XCTUnwrap(reminder.nextOccurrence())
        XCTAssertGreaterThan(next, .now)

        let parts = Calendar.current.dateComponents([.hour, .minute], from: next)
        XCTAssertEqual(parts.hour, 7)
        XCTAssertEqual(parts.minute, 15)
    }

    func testNextOccurrenceOnlyUsesSelectedDays() throws {
        // Sunday only.
        let reminder = makeReminder(mask: 1 << 0)

        let next = try XCTUnwrap(reminder.nextOccurrence())
        XCTAssertEqual(Calendar.current.component(.weekday, from: next), 1)
    }

    func testDisabledReminderHasNoNextOccurrence() {
        let reminder = makeReminder(mask: Reminder.everyDay)
        reminder.isEnabled = false

        XCTAssertNil(reminder.nextOccurrence())
    }

    func testNoDaysMeansNoNextOccurrence() {
        XCTAssertNil(makeReminder(mask: 0).nextOccurrence())
    }
}
