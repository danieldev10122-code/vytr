import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "circle.dashed") }

            PlaceholderView(
                title: "Journal",
                systemImage: "square.grid.2x2",
                message: "Your meal history will live here, searchable by name and date."
            )
            .tabItem { Label("Journal", systemImage: "square.grid.2x2") }

            PlaceholderView(
                title: "Training",
                systemImage: "dumbbell",
                message: "Your weekly plan, today's exercises and completed sessions."
            )
            .tabItem { Label("Training", systemImage: "dumbbell") }

            SettingsView()
                .tabItem { Label("More", systemImage: "slider.horizontal.3") }
        }
        .tint(Theme.Palette.accent)
    }
}
