import SwiftUI
import UIKit

struct SettingsView: View {
    @State private var keyInput = ""
    @State private var hasKey = KeychainStore.hasKey
    @State private var message: String?
    @State private var showRemoveConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        keyCard
                        privacyCard
                        goalsNote
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Remove the saved API key?",
                isPresented: $showRemoveConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove key", role: .destructive) {
                    KeychainStore.delete()
                    hasKey = false
                    keyInput = ""
                    message = "Key removed. AI analysis is off."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Meals already saved are not affected.")
            }
        }
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "AI analysis")

            HStack(spacing: Theme.Spacing.s) {
                Circle()
                    .fill(hasKey ? Theme.Palette.accent : Theme.Palette.textTertiary)
                    .frame(width: 8, height: 8)
                Text(hasKey ? "Key saved on this device" : "No key saved")
                    .font(.vytrBody)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            if hasKey {
                Button(role: .destructive) {
                    showRemoveConfirm = true
                } label: {
                    Text("Remove key")
                        .font(.vytrBody.weight(.medium))
                        .foregroundStyle(.red)
                }
            } else {
                SecureField("Paste your Gemini API key", text: $keyInput)
                    .font(.vytrBody)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(Theme.Spacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .fill(Theme.Palette.surfaceRaised)
                    )

                Button(action: saveKey) {
                    Text("Save key")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(
                                keyInput.isEmpty ? Theme.Palette.textTertiary : Theme.Palette.accent
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(keyInput.isEmpty)

                Text("Get a free key at aistudio.google.com/apikey")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            if let message {
                Text(message)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .vytrCard()
    }

    /// Stated plainly in the app, not only in a conversation, because this
    /// is where the choice is actually made.
    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "What leaves this device")

            Text("Nothing is sent anywhere unless you tap Analyze on a photo. Meals, photos and workouts are stored only on this iPhone.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("When you do tap Analyze, that one photo is sent to Google's Gemini API. On the free tier Google states that it uses submitted content to improve its products, and that human reviewers may read and annotate it. Google advises against sending personal information to the free tier.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vytrCard()
    }

    private var goalsNote: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "About the numbers")
            Text("Calorie figures from a photo are estimates, not measurements, and are shown as ranges. This app is for building habits, not for medical or dietary instruction.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vytrCard()
    }

    private func saveKey() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainStore.save(trimmed)
            hasKey = true
            keyInput = ""
            message = "Key saved to the iOS Keychain."
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            message = error.localizedDescription
        }
    }
}
