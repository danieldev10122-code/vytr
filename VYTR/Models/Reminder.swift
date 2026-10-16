import Foundation
import SwiftData

@Model
final class Reminder {
    var title: String
    var hour: Int
    var minute: Int

    /// Days as a bitmask, bit 0 Sunday through bit 6 Saturday, matching
    /// Calendar's 1-7 weekday numbering shifted by one. A mask rather than
    /// an array keeps a reminder a single row with no ordering to manage.
    var weekdayMask: Int

    var isEnabled: Bool
    var createdAt: Date

    init(
        title: String,
        hour: Int,
        minute: Int,
        weekdayMask: Int = Reminder.everyDay,
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.title = title
        self.hour = hour
        self.minute = minute
        self.weekdayMask = weekdayMask
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    static let everyDay = 0b1111111

    /// Calendar weekday numbers (1 = Sunday) this reminder fires on.
    var weekdays: [Int] {
        (1...7).filter { weekdayMask & (1 << ($0 - 1)) != 0 }
    }

    var timeText: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// "Every day", "Weekdays", "Mon, Wed, Fri" - whichever is shortest to
    /// read at a glance.
    var daysText: String {
        let days = weekdays
        if days.count == 7 { return "Every day" }
        if days.isEmpty { return "No days selected" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days == [1, 7] { return "Weekends" }

        let symbols = Calendar.current.shortWeekdaySymbols
        return days.map { symbols[$0 - 1] }.joined(separator: ", ")
    }

    /// When this fires next, used to show the soonest reminder on Today.
    func nextOccurrence(after date: Date = .now) -> Date? {
        guard isEnabled else { return nil }
        let calendar = Calendar.current

        return weekdays.compactMap { weekday in
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = weekday
            return calendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTimePreservingSmallerComponents
            )
        }
        .min()
    }
}
