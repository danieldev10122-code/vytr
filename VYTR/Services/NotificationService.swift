import Foundation
import UserNotifications

/// Schedules reminders as local notifications.
///
/// Local notifications need no entitlement and no server, which is why
/// they work on a free signing certificate where remote push would not.
/// Everything here stays on the device.
enum NotificationService {

    private static var center: UNUserNotificationCenter { .current() }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Returns whether notifications may now be shown. Asking twice is
    /// harmless: iOS only presents its prompt once and answers from the
    /// stored decision afterwards.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Identifier prefixes. Reminders and one-off tests are kept apart so
    /// that rewriting the schedule cannot touch anything else.
    private static let reminderPrefix = "reminder-"
    private static let workoutPrefix = "workout-"
    private static let testPrefix = "vytr-test-"

    /// Rewrites the schedule from the reminders given.
    ///
    /// Replacing every reminder rather than patching individual requests
    /// keeps the scheduled notifications and the stored reminders from
    /// drifting apart, which is the usual source of a reminder that fires
    /// after it was deleted.
    ///
    /// Only reminder requests are cleared. This used to call
    /// removeAllPendingNotificationRequests, which also deleted the
    /// five-second test notification a moment after it was scheduled, so
    /// the test could never fire while real reminders worked fine.
    static func reschedule(_ reminders: [Reminder]) async {
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(reminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        for reminder in reminders where reminder.isEnabled {
            let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            for weekday in reminder.weekdays {
                let content = UNMutableNotificationContent()
                content.title = title
                content.sound = .default

                var components = DateComponents()
                components.hour = reminder.hour
                components.minute = reminder.minute
                components.weekday = weekday

                // One repeating request per weekday, so a reminder set for
                // Monday and Thursday is two weekly repeats rather than a
                // daily one that has to be filtered at delivery time.
                let request = UNNotificationRequest(
                    identifier: "\(reminderPrefix)\(reminder.persistentModelID.hashValue)-\(weekday)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                )

                try? await center.add(request)
            }
        }
    }

    /// Schedules the pre-session nudge for upcoming workouts.
    ///
    /// These fire once rather than weekly, because a repeating workout
    /// only exists one session at a time: completing it creates the next
    /// one, and that one is scheduled when this runs again.
    static func rescheduleWorkouts(_ workouts: [Workout]) async {
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(workoutPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        for workout in workouts {
            guard let fireDate = workout.reminderDate else { continue }

            let content = UNMutableNotificationContent()
            content.title = workout.name
            content.body = "Starts at \(workout.timeText)."
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )

            let request = UNNotificationRequest(
                identifier: "\(workoutPrefix)\(workout.persistentModelID.hashValue)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            try? await center.add(request)
        }
    }

    /// How many reminder notifications iOS currently holds. Shown in the
    /// UI so the schedule can be seen rather than taken on trust. Tests
    /// are excluded so a pending test cannot inflate the count.
    static func pendingCount() async -> Int {
        await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(reminderPrefix) }
            .count
    }

    /// Fires a notification a few seconds from now, so the whole path -
    /// permission, scheduling, delivery - can be checked without waiting
    /// for a real reminder time.
    ///
    /// Returns a sentence describing what actually happened. "It did not
    /// work" is not a diagnosis, and every step here can fail for a
    /// different reason that the user can act on.
    static func sendTestNotification() async -> String {
        let status = await authorizationStatus()

        switch status {
        case .denied:
            return "iOS is blocking notifications for VYTR. Turn them on in iOS Settings > VYTR > Notifications."
        case .notDetermined:
            guard await requestAuthorization() else {
                return "Permission was not granted, so nothing can be shown."
            }
        default:
            break
        }

        let settings = await center.notificationSettings()
        guard settings.alertSetting != .disabled else {
            return "Notifications are allowed but banners are switched off in iOS Settings > VYTR > Notifications."
        }

        let content = UNMutableNotificationContent()
        content.title = "VYTR reminders work"
        content.body = "This is a test notification from your iPhone."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(testPrefix)\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )

        do {
            try await center.add(request)
            return "Test accepted by iOS. It should appear in about 5 seconds, here or on the lock screen."
        } catch {
            return "iOS refused the test: \(error.localizedDescription)"
        }
    }
}
