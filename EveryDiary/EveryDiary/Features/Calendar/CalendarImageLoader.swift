import Foundation
import UIKit

@MainActor
protocol CalendarImageLoading {
    func image(for url: URL) async -> UIImage?
}

@MainActor
final class CachedCalendarImageLoader: CalendarImageLoading {
    private let cache: ImageCacheManager

    init(cache: ImageCacheManager) {
        self.cache = cache
    }

    func image(for url: URL) async -> UIImage? {
        // The existing cache completes once. The view ignores results from cancelled tasks;
        // transport cancellation can be added when the shared image service exposes it.
        await withCheckedContinuation { continuation in
            cache.loadImage(from: url) { continuation.resume(returning: $0) }
        }
    }
}
