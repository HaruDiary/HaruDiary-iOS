import Foundation
import UIKit

@MainActor
final class CachedCalendarImageLoader: CalendarImageLoading {
    private let cache: ImageCacheManager

    init(cache: ImageCacheManager) {
        self.cache = cache
    }

    func image(for url: URL) async -> UIImage? {
        // The cache completes once, with a thumbnail-sized image. The view ignores results from cancelled tasks.
        await withCheckedContinuation { continuation in
            cache.loadImage(from: url) { continuation.resume(returning: $0) }
        }
    }
}
