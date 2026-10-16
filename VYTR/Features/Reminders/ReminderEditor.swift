import SwiftUI
import SwiftData

struct ReminderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// nil creates a new reminder, otherwise this one is edited in place.
    let existing: Reminder?

    @State private var title = ""
    @State private var time = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? .now
    @State private var mask = Reminder.everyDay

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mask != 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Palette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        VStack(spacing: 0) {
                            FormField(
                                label: "Remind me",
                                placeholder: "Leave for the gym",
                                text: $title
                            )
                        }
                        .vytrCard()

                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            SectionLabel(text: "Time")
                            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                                .tint(Theme.Palette.accent)
                        }
                        .vytrCard()

                        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                            SectionLabel(text: "Days")
                            WeekdayPicker(mask: $mask)
                            if mask == 0 {
                                Text("Pick at least one day.")
                                    .font(.vytrCaption)
                                    .foregroundStyle(Theme.Palette.fat)
                            }
                        }
                        .vytrCard()
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationTitle(existing == nil ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Theme.Palette.accent : Theme.Palette.textTertiary)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let existing else { return }
        title = existing.title
        mask = existing.weekdayMask
        var components = DateComponents()
        components.hour = existing.hour
        components.minute = existing.minute
        time = Calendar.current.date(from: components) ?? time
    }

    private func save() {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing {
            existing.title = trimmed
            existing.hour = parts.hour ?? 0
            existing.minute = parts.minute ?? 0
            existing.weekdayMask = mask
        } else {
            context.insert(
                Reminder(
                    title: trimmed,
                    hour: parts.hour ?? 0,
                    minute: parts.minute ?? 0,
                    weekdayMask: mask
                )
            )
        }

        try? context.save()
        dismiss()
    }
}

/// Seven taps, Sunday first, matching Calendar's weekday numbering.
struct WeekdayPicker: View {
    @Binding var mask: Int

    private let symbols = Calendar.current.veryShortWeekdaySymbols

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(1...7, id: \.self) { weekday in
                let selected = mask & (1 << (weekday - 1)) != 0

                Button {
                    withAnimation(Theme.Motion.spring) {
                        mask ^= (1 << (weekday - 1))
                    }
                } label: {
                    Text(symbols[weekday - 1])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? Theme.Palette.background : Theme.Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            Circle().fill(selected ? Theme.Palette.accent : Theme.Palette.surfaceRaised)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
