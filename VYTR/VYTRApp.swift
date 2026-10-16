import SwiftUI
import SwiftData

@main
struct VYTRApp: App {
    /// All data stays on the device. No account, no sync, no server.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Meal.self, Workout.self, Reminder.self)
        } catch {
            fatalError("Could not create the local data store: \(error)")
        }
    }()

    init() {
        // Must be set before any notification can arrive, so reminders
        // appear even while VYTR is the app on screen.
        NotificationPresenter.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
