import UIKit
import ImageIO

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

    /// A smaller rendition used only for the API call. The journal keeps
    /// the larger copy; the model does not need it to recognise food.
    static func forAnalysis(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return prepare(image, maxDimension: 1024, quality: 0.7)
    }

    /// Builds a small image straight from the encoded data.
    ///
    /// UIImage(data:) decodes the whole picture: a 1280px JPEG fully
    /// expanded in memory just to fill a 40pt square, on every redraw of
    /// every row. ImageIO reads the file's structure and produces the
    /// size asked for without ever materialising the full bitmap, which
    /// is what makes a long journal scroll smoothly.
    static func thumbnail(from data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
