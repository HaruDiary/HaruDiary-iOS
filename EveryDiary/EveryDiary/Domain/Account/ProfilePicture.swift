import Foundation

/// What the profile shows: one of the built-in avatars or a photo the member uploaded.
enum ProfilePicture: Equatable {
    case avatar(ProfileAvatar)
    case photo(URL)

    /// Uploaded profile photos are stored as `{uid}/profile-….jpg` in the app's Storage bucket.
    static let photoFilePrefix = "profile-"

    /// Reads the Firebase Auth photo URL. Photos from Google/Apple or other files are not treated
    /// as the member's upload and give nil, so the default avatar is shown.
    init?(storedURL: String?) {
        if let avatar = ProfileAvatar(storedURL: storedURL) {
            self = .avatar(avatar)
        } else if let storedURL, let url = URL(string: storedURL), Self.isUploadedPhoto(url) {
            self = .photo(url)
        } else {
            return nil
        }
    }

    static func isUploadedPhoto(_ url: URL) -> Bool {
        guard url.scheme == "https", url.host?.hasSuffix("firebasestorage.googleapis.com") == true,
              let range = url.path.range(of: "/o/") else { return false }
        // The object path is percent-encoded after /o/, e.g. `uid%2Fprofile-….jpg`.
        let objectPath = String(url.path[range.upperBound...]).removingPercentEncoding ?? ""
        let parts = objectPath.split(separator: "/")
        return parts.count == 2 && parts[1].hasPrefix(photoFilePrefix)
    }
}

/// The picture chosen in the profile editor.
enum ProfilePictureSelection: Equatable {
    case avatar(ProfileAvatar)
    /// Keeps the photo already on the profile.
    case currentPhoto(URL)
    /// A new photo, already cropped and re-encoded as JPEG without location metadata.
    case newPhoto(Data)
}
