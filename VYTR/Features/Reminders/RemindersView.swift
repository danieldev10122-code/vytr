import SwiftUI
import UIKit
import SwiftData
import UserNotifications

struct RemindersView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Reminder.hour, order: .forward)
    private var reminders: [Reminder]

    @State private var editing: Reminder?
    @State private var showEditor = false
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var pending = 0
    @State private var testMessage: String?

    private var permissionGranted: Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    if !permissionGranted { permissionCard }
                    list
                    if permissionGranted { statusCard }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
        }
        .sheet(isPresented: $showEditor, onDismiss: refresh) {
            ReminderEditor(existing: editing)
        }
        .task { await load() }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Notifications are off")

            Text(status == .denied
                 ? "Notifications were turned down earlier. Reminders can only appear once they are switched back on in iOS Settings, under VYTR."
                 : "VYTR needs permission to show reminders. They are scheduled by iOS on this device, with no server involved.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if status == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    actionLabel("Open iOS Settings")
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Task {
                        await NotificationService.requestAuthorization()
                        await load()
                    }
                } label: {
                    actionLabel("Allow notifications")
                }
                .buttonStyle(.plain)
            }
        }
        .vytrCard()
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "Your reminders")

            if reminders.isEmpty {
                EmptyStateView(
                    systemImage: "bell",
                    title: "No reminders yet",
                    message: "Add one with the plus button to be nudged at a time you choose."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(reminders) { reminder in
                        row(reminder)
                        if reminder.id != reminders.last?.id {
                            Divider().overlay(Theme.Palette.separator)
                        }
                    }
                }
            }
        }
        .vytrCard()
    }

    private func row(_ reminder: Reminder) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.timeText)
                    .font(.system(size: 20, weight: .light, design: .rounded))
                    .foregroundStyle(reminder.isEnabled ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                Text(reminder.title)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                Text(reminder.daysText)
                    .font(.vytrLabel)
                    .tracking(1)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            Spacer(minLength: Theme.Spacing.s)

            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { newValue in
                    reminder.isEnabled = newValue
                    try? context.save()
                    refresh()
                }
            ))
            .labelsHidden()
            .tint(Theme.Palette.accent)
        }
        .padding(.vertical, Theme.Spacing.s)
        .contentShape(Rectangle())
        .onTapGesture {
            editing = reminder
            showEditor = true
        }
        .contextMenu {
            Button(role: .destructive) {
                context.delete(reminder)
                try? context.save()
                refresh()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Shows what iOS actually holds, rather than asserting that the
    /// schedule was written.
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "Scheduled with iOS")

            Text(pending == 0
                 ? "Nothing scheduled yet."
                 : "\(pending) notification\(pending == 1 ? "" : "s") queued, one per day each reminder repeats on.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textSecondary)

            Button {
                Task {
                    let sent = await NotificationService.sendTestNotification()
                    testMessage = sent
                        ? "Test sent. It should appear in about 5 seconds - lock the phone to see it arrive."
                        : "Could not schedule a test notification."
                }
            } label: {
                actionLabel("Send a test notification")
            }
            .buttonStyle(.plain)

            if let testMessage {
                Text(testMessage)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .vytrCard()
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Palette.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.Palette.accent))
    }

    private func refresh() {
        Task { await load() }
    }

    private func load() async {
        status = await NotificationService.authorizationStatus()
        if permissionGranted {
            await NotificationService.reschedule(reminders)
        }
        pending = await NotificationService.pendingCount()
    }
}
