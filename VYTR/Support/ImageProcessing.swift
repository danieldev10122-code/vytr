import UIKit

enum ImageProcessing {

    /// Downscales and re-encodes a photo before it is stored.
    ///
    /// A full-resolution iPhone photo is several megabytes; a meal
    /// thumbnail does not need that. Drawing into a fresh context also
    /// normalises orientation, so a photo taken sideways is stored the
    /// way it was seen.
    static func prepare(
        _ image: UIImage,
        maxDimension: CGFloat = 1280,
        quality: CGFloat = 0.8
    ) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }

        return resized.jpegData(compressionQuality: quality)
    }
}
