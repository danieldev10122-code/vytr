import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "circle.dashed") }

            JournalView()
                .tabItem { Label("Journal", systemImage: "square.grid.2x2") }

            TrainingView()
                .tabItem { Label("Training", systemImage: "dumbbell") }

            SettingsView()
                .tabItem { Label("More", systemImage: "slider.horizontal.3") }
        }
        .tint(Theme.Palette.accent)
    }
}
