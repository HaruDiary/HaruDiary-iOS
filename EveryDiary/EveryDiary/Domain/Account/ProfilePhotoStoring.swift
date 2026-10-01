import Foundation

/// The member's uploaded profile photo, kept on the device so it is shown without downloading it again.
@MainActor
protocol ProfilePhotoStoring: AnyObject {
    /// Keeps `jpeg` as the photo at `url` and drops any photo kept before; only one profile photo is shown.
    func store(_ jpeg: Data, for url: URL)
    func removeAll()
    /// Drops every kept photo but the one at `url`: after another account signed in, the previous account's
    /// photo must not stay on the device, while the photo this account shows stays to be shown at once.
    func keepOnly(_ url: URL)
}
