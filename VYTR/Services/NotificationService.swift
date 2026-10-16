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

    /// Rewrites the whole schedule from the reminders given.
    ///
    /// Replacing everything rather than patching individual requests keeps
    /// the scheduled notifications and the stored reminders from drifting
    /// apart, which is the usual source of a reminder that fires after it
    /// was deleted.
    static func reschedule(_ reminders: [Reminder]) async {
        center.removeAllPendingNotificationRequests()

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
                    identifier: "\(reminder.persistentModelID.hashValue)-\(weekday)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                )

                try? await center.add(request)
            }
        }
    }

    /// How many notifications iOS currently holds. Shown in the UI so the
    /// schedule can be seen rather than taken on trust.
    static func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    /// Fires a notification a few seconds from now, so the whole path -
    /// permission, scheduling, delivery - can be checked without waiting
    /// for a real reminder time.
    static func sendTestNotification() async -> Bool {
        guard await requestAuthorization() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "VYTR reminders work"
        content.body = "This is a test notification from your iPhone."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "vytr-test-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )

        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
