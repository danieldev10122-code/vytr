import SwiftUI
import SwiftData

@main
struct VYTRApp: App {
    @Environment(\.scenePhase) private var scenePhase

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
                // Restores the notification schedule, which iOS clears on
                // every reinstall - and this app is reinstalled weekly.
                .task { await ScheduleSync.run(container: container) }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await ScheduleSync.run(container: container) }
                }
        }
        .modelContainer(container)
    }
}
