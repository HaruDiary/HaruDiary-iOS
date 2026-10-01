import Foundation

/// The member's uploaded profile photo, kept on the device so it is shown without downloading it again.
@MainActor
protocol ProfilePhotoStoring: AnyObject {
    /// Keeps `jpeg` as the photo at `url` and drops any photo kept before; only one profile photo is shown.
    func store(_ jpeg: Data, for url: URL)
    func removeAll()
}
