import SwiftUI
import UIKit

/// Keeps decoded thumbnails around between redraws.
///
/// A SwiftUI row rebuilds whenever anything it depends on changes, and
/// without a cache every rebuild decoded the photo again. NSCache is used
/// rather than a dictionary because it releases itself under memory
/// pressure instead of growing until the system intervenes. NSCache is
/// already thread safe, so this needs no actor isolation of its own.
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    func image(for data: Data, key: String, maxPixel: CGFloat) -> UIImage? {
        let cacheKey = "\(key)-\(Int(maxPixel))" as NSString

        if let hit = cache.object(forKey: cacheKey) { return hit }

        guard let image = ImageProcessing.thumbnail(from: data, maxPixel: maxPixel) else {
            return nil
        }

        cache.setObject(image, forKey: cacheKey)
        return image
    }
}

/// A meal's photo at row size, or a placeholder when there is none.
struct MealThumbnail: View {
    let meal: Meal
    var side: CGFloat = 44

    private var image: UIImage? {
        guard let data = meal.photo else { return nil }
        return ThumbnailCache.shared.image(
            for: data,
            key: "\(meal.persistentModelID)",
            // Asking for the pixel size the screen will actually use.
            maxPixel: side * 3
        )
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.thumbnail, style: .continuous)
            .fill(Theme.Palette.surfaceRaised)
            .frame(width: side, height: side)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipShape(
                            RoundedRectangle(cornerRadius: Theme.Radius.thumbnail, style: .continuous)
                        )
                } else {
                    Image(systemName: "fork.knife")
                        .font(.vytrCaption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            .accessibilityHidden(true)
    }
}
