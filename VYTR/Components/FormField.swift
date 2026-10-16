import SwiftUI
import UIKit

/// One labelled row inside a form card.
struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var suffix: String?
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            // Sized by its own text rather than a fixed width, so a
            // larger Dynamic Type setting widens the label instead of
            // truncating it.
            Text(label)
                .font(.vytrBody)
                .foregroundStyle(Theme.Palette.textSecondary)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 76, alignment: .leading)

            TextField(placeholder, text: $text)
                .font(.vytrBody)
                .foregroundStyle(Theme.Palette.textPrimary)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.sentences)

            if let suffix {
                Text(suffix)
                    .font(.vytrCaption)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(width: 30, alignment: .leading)
            }
        }
        .padding(.vertical, Theme.Spacing.s)
    }
}
