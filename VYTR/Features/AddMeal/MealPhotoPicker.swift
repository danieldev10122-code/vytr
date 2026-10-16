import SwiftUI
import UIKit
import PhotosUI

/// The photo area at the top of the add-meal form. A photo is optional;
/// a meal can be logged without one.
struct MealPhotoPicker: View {
    @Binding var imageData: Data?
    @Binding var showCamera: Bool
    @State private var libraryItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            preview

            HStack(spacing: Theme.Spacing.m) {
                if CameraPicker.isAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        actionLabel("Camera", systemImage: "camera")
                    }
                }

                PhotosPicker(selection: $libraryItem, matching: .images, photoLibrary: .shared()) {
                    actionLabel("Library", systemImage: "photo.on.rectangle")
                }

                if imageData != nil {
                    Button(role: .destructive) {
                        imageData = nil
                        libraryItem = nil
                    } label: {
                        actionLabel("Remove", systemImage: "trash")
                    }
                }
            }
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: raw) {
                    await MainActor.run { imageData = ImageProcessing.prepare(image) }
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Theme.Palette.surfaceRaised)
            .frame(height: 190)
            .overlay {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                } else {
                    VStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .light))
                        Text("Photo optional")
                            .font(.vytrCaption)
                    }
                    .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .clipped()
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.vytrCaption.weight(.medium))
        .foregroundStyle(Theme.Palette.textSecondary)
        .padding(.vertical, Theme.Spacing.s)
        .padding(.horizontal, Theme.Spacing.m)
        .background(
            Capsule().fill(Theme.Palette.surfaceRaised)
        )
    }
}
