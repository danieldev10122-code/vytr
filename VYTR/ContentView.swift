import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.vytrBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("VYTR")
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .tracking(10)
                    .foregroundStyle(.white)

                Text("BUILD CHAIN VERIFIED")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Color.vytrAccent)

                Text("Stage 1")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 2)
            }
        }
    }
}

extension Color {
    /// Near-black base of the Dark Premium palette.
    static let vytrBackground = Color(red: 0.04, green: 0.05, blue: 0.06)
    /// Single lime accent used for positive state.
    static let vytrAccent = Color(red: 0.72, green: 0.95, blue: 0.40)
}

#Preview {
    ContentView()
}
