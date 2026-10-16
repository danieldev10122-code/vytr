import SwiftUI
import SwiftData

@main
struct VYTRApp: App {
    /// All data stays on the device. No account, no sync, no server.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Meal.self, Workout.self)
        } catch {
            fatalError("Could not create the local data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
