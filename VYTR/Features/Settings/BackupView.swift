import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export and import, the only way to get this app's data off the phone
/// without backing up the whole device.
///
/// Import is deliberately slow to trigger: pick a file, read what it
/// contains, see exactly how many entries would be added, and only then
/// confirm. Nothing is ever deleted or overwritten by it.
struct BackupView: View {
    @Environment(\.modelContext) private var context

    @Query private var meals: [Meal]
    @Query private var workouts: [Workout]
    @Query private var reminders: [Reminder]

    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var exportError: String?

    @State private var isPicking = false
    @State private var isReading = false
    @State private var importError: String?
    @State private var plan: BackupService.Plan?
    @State private var importResult: String?

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    exportCard
                    importCard
                    formatCard
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isPicking,
            allowedContentTypes: [.zip, .data],
            allowsMultipleSelection: false
        ) { result in
            read(result)
        }
        .sheet(item: $plan) { plan in
            ImportPreviewSheet(plan: plan) {
                apply(plan)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Export

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Save a copy")

            Text("Writes everything in VYTR to one file: \(meals.count) \(meals.count == 1 ? "meal" : "meals"), \(workouts.count) \(workouts.count == 1 ? "workout" : "workouts"), \(reminders.count) \(reminders.count == 1 ? "reminder" : "reminders"), with the meal photos inside it.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let exportURL {
                ShareLink(item: exportURL, preview: SharePreview(exportURL.lastPathComponent)) {
                    VytrButtonLabel(title: "Share the backup", systemImage: "square.and.arrow.up")
                }
                .pressable()

                Text("\(exportURL.lastPathComponent) is ready. Send it to Files, iCloud Drive or another device.")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VytrButton(
                    title: "Create a backup file",
                    systemImage: "arrow.down.doc",
                    isLoading: isExporting,
                    action: export
                )
            }

            if let exportError {
                Text(exportError)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .vytrCard()
    }

    private func export() {
        isExporting = true
        exportError = nil
        // Reading every photo out of the store takes long enough to drop
        // a frame on a full journal, so it does not happen on the main
        // actor. A separate context on a background task is the supported
        // way to touch SwiftData off it.
        let container = context.container
        Task {
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try BackupService.exportFile(context: ModelContext(container))
                }.value
                exportURL = url
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    // MARK: - Import

    private var importCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SectionLabel(text: "Restore from a file")

            Text("Adds back anything from a backup that is not already here. Nothing in VYTR is deleted or changed, and you see the exact numbers before it happens.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VytrButton(
                title: "Choose a backup file",
                systemImage: "arrow.up.doc",
                kind: .secondary,
                isLoading: isReading
            ) {
                importError = nil
                importResult = nil
                isPicking = true
            }

            if let importResult {
                Text(importResult)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let importError {
                Text(importError)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .vytrCard()
    }

    private func read(_ result: Result<[URL], Error>) {
        isReading = true
        defer { isReading = false }

        do {
            guard let url = try result.get().first else { return }

            // A file picked from Files lives outside the sandbox and has
            // to be opened through its security scope, or reading it
            // fails with a permission error.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            plan = try BackupService.plan(forImporting: data, context: context)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func apply(_ plan: BackupService.Plan) {
        self.plan = nil
        do {
            let added = try BackupService.apply(plan, context: context)
            importResult = added == 0
                ? "Everything in that file was already here. Nothing changed."
                : "Added \(added) \(added == 1 ? "entry" : "entries")."

            // Imported reminders and workouts mean nothing until iOS has
            // been told about them. This is the same pass the app runs at
            // launch, so the schedule ends up matching the store exactly.
            let container = context.container
            Task { await ScheduleSync.run(container: container) }
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - What the file is

    private var formatCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(text: "About the file")

            Text("The backup is an ordinary zip. Open it on a computer and you will find manifest.json with the numbers in plain text, and a photos folder with the pictures as JPEGs.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("It is not encrypted, so keep it wherever you keep private files. It never leaves this iPhone unless you send it somewhere.")
                .font(.vytrCaption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vytrCard()
    }
}

// MARK: - Confirmation

/// States what the import will do, in counts, before it does it.
private struct ImportPreviewSheet: View {
    let plan: BackupService.Plan
    let confirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.Palette.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionLabel(text: "This backup")
                    Text("Saved \(plan.document.exportedAt.formatted(date: .abbreviated, time: .shortened)), holding \(plan.document.entryCount) \(plan.document.entryCount == 1 ? "entry" : "entries").")
                        .font(.vytrBody)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionLabel(text: "What will be added")
                    row("Meals", plan.newMeals.count)
                    row("Workouts", plan.newWorkouts.count)
                    row("Reminders", plan.newReminders.count)

                    if plan.alreadyPresentCount > 0 {
                        Text("\(plan.alreadyPresentCount) already here, so they will be skipped.")
                            .font(.vytrCaption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }

                Text("Nothing already in VYTR is deleted or changed.")
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)

                Spacer(minLength: 0)

                VytrButton(
                    title: plan.isEmpty
                        ? "Nothing to add"
                        : "Add \(plan.newCount) \(plan.newCount == 1 ? "entry" : "entries")",
                    systemImage: "plus",
                    action: confirm
                )
                .disabled(plan.isEmpty)

                VytrButton(title: "Cancel", kind: .secondary) { dismiss() }
            }
            .padding(Theme.Spacing.m)
        }
    }

    private func row(_ label: String, _ count: Int) -> some View {
        HStack {
            Text(label)
                .font(.vytrBody)
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text("\(count)")
                .font(.vytrNumeric)
                .foregroundStyle(count > 0 ? Theme.Palette.accent : Theme.Palette.textTertiary)
        }
    }
}

/// Needed so the plan can drive a sheet directly: the sheet exists only
/// while there is a plan to confirm.
extension BackupService.Plan: Identifiable {
    var id: String {
        "\(document.exportedAt.timeIntervalSince1970)-\(newCount)-\(document.entryCount)"
    }
}
