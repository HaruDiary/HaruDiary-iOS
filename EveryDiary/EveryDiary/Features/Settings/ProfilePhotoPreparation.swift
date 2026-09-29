import UIKit

/// Turns a photo from the library into the uploaded profile image.
enum ProfilePhotoPreparation {
    static let side: CGFloat = 512

    /// Center-cropped square, at most 512 px, re-encoded as JPEG. Re-encoding drops the original
    /// metadata (location, capture details). Returns nil when the data is not a readable image.
    static func prepare(_ data: Data) -> (image: UIImage, jpeg: Data)? {
        guard let source = UIImage(data: data), source.size.width > 0, source.size.height > 0 else { return nil }
        let shortest = min(source.size.width, source.size.height)
        let target = min(side, shortest * source.scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: target, height: target), format: format).image { _ in
            let scale = target / shortest
            let drawSize = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            source.draw(in: CGRect(x: (target - drawSize.width) / 2, y: (target - drawSize.height) / 2,
                                   width: drawSize.width, height: drawSize.height))
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.8) else { return nil }
        return (image, jpeg)
    }
}
