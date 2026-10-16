import Foundation
import UserNotifications

/// Shows notifications even while VYTR is the app on screen.
///
/// Without a delegate, iOS delivers a notification silently when its own
/// app is in the foreground. That is sensible for a chat app, but it
/// makes a reminder look broken when the user is sitting in the very
/// screen that scheduled it.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationPresenter()

    private override init() { super.init() }

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
