import Foundation
import SwiftData

/// Rewrites the whole notification schedule from what is in the store.
///
/// iOS discards an app's pending notifications when it is reinstalled,
/// and VYTR is reinstalled every week when its free signature is
/// renewed. Scheduling only from the Reminders and Training screens
/// meant that after each re-sign the reminders were silently gone until
/// those screens happened to be opened. This runs at launch and whenever
/// the app returns to the foreground, so the schedule is restored
/// without the user having to know any of that.
enum ScheduleSync {

    static func run(container: ModelContainer) async {
        // Nothing can be scheduled without permission, and asking here
        // would put a system prompt in front of someone who just opened
        // the app. The Reminders screen asks, in context.
        let status = await NotificationService.authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        let context = ModelContext(container)

        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []

        await NotificationService.reschedule(reminders)
        await NotificationService.rescheduleWorkouts(workouts)
    }
}
