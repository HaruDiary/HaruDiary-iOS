//
//  ImageCacheManager.swift
//  EveryDiary
//
//  Created by t2023-m0026 on 3/11/24.
//

import ImageIO
import UIKit

/// Thumbnails for the diary rows (list, calendar, trash). A stored photo is several megapixels, so it is
/// decoded at thumbnail size, off the main thread, and the cache is bounded.
class ImageCacheManager {
    static let shared = ImageCacheManager()
    /// The largest thumbnail is 80pt; at 3x that is 240 pixels.
    static let maxPixelSize = 320

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    /// Requests for a URL already being loaded wait for that one download.
    private var waiting: [String: [(UIImage?) -> Void]] = [:]

    private init() {
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    /// The completion runs on the main thread.
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let key = url.absoluteString
        if let cached = cache.object(forKey: key as NSString) {
            completion(cached)
            return
        }
        lock.lock()
        let isFirst = waiting[key] == nil
        waiting[key, default: []].append(completion)
        lock.unlock()
        guard isFirst else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            let image = data.flatMap(Self.thumbnail(from:))
            if let image {
                self.cache.setObject(image, forKey: key as NSString, cost: Self.cost(of: image))
            }
            self.lock.lock()
            let completions = self.waiting.removeValue(forKey: key) ?? []
            self.lock.unlock()
            DispatchQueue.main.async {
                completions.forEach { $0(image) }
            }
        }.resume()
    }

    private static func thumbnail(from data: Data) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options).map { UIImage(cgImage: $0) }
    }

    private static func cost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
