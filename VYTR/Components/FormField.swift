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
            Text(label)
                .font(.vytrBody)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 86, alignment: .leading)

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
