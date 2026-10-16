import SwiftUI

/// Stands in for a tab that has not been built yet, so the navigation
/// shape is real while the features arrive one at a time.
struct PlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()
                EmptyStateView(
                    systemImage: systemImage,
                    title: title,
                    message: message
                )
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
