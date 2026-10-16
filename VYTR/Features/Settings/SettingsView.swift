import SwiftUI
import UIKit

struct SettingsView: View {
    @State private var keyInput = ""
    @State private var hasKey = KeychainStore.hasKey
    @State private var message: String?
    @State private var showRemoveConfirm = false
    @State private var diagnostics: [GeminiDiagnostics.Result] = []
    @State private var isDiagnosing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        remindersLink
                        goalsLink
                        keyCard
                        if hasKey { diagnosticCard }
                        privacyCard
                        goalsNote
                        aboutCard
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
                VytrButton(title: "Remove key", kind: .destructive) {
                    showRemoveConfirm = true
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

                VytrButton(title: "Save key", systemImage: "key.fill", action: saveKey)
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

    private var goalsLink: some View {
        NavigationLink {
            GoalsView()
        } label: {
            navRow(
                icon: "target",
                title: "Daily targets",
                subtitle: "Calories and macros you are aiming for"
            )
        }
        .buttonStyle(.plain)
    }

    private func navRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.Palette.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.vytrBody.weight(.medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .vytrCard()
    }

    private var remindersLink: some View {
        NavigationLink {
            RemindersView()
        } label: {
            navRow(
                icon: "bell",
                title: "Reminders",
                subtitle: "Times and days you choose, scheduled on this device"
            )
        }
        .buttonStyle(.plain)
    }

    /// Sends a few deliberately tiny requests so a failure can be read as
    /// a measurement rather than guessed at from one opaque error.
    private var diagnosticCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Connection test")

            Text("Sends a few very small requests to Gemini, one ingredient at a time, and times each. No photo of yours is used.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if !diagnostics.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(diagnostics) { result in
                        HStack(alignment: .top, spacing: Theme.Spacing.s) {
                            Image(systemName: result.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(result.ok ? Theme.Palette.accent : .red)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.step)
                                    .font(.vytrCaption.weight(.medium))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                Text(result.outcome)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Theme.Palette.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            VytrButton(
                title: "Run connection test",
                kind: .secondary,
                isLoading: isDiagnosing
            ) {
                Task {
                    isDiagnosing = true
                    diagnostics = await GeminiDiagnostics.run()
                    isDiagnosing = false
                }
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

    /// The app knows when its own signature runs out, so the seven-day
    /// limit does not have to be remembered or guessed at.
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "This build")

            HStack(spacing: Theme.Spacing.s) {
                Circle()
                    .fill(SigningInfo.isExpiringSoon ? Theme.Palette.fat : Theme.Palette.accent)
                    .frame(width: 8, height: 8)
                Text("VYTR \(SigningInfo.version)")
                    .font(.vytrBody)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            Text(SigningInfo.expiryText)
                .font(.vytrCaption)
                .foregroundStyle(SigningInfo.isExpiringSoon
                                 ? Theme.Palette.fat
                                 : Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Re-signing keeps your meals, workouts and reminders. Connect the iPhone, open Sideloadly, drop in the same VYTR.ipa and press Start.")
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
