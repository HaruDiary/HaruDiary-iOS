import Foundation

/// The profile picture a member picks. Stored as the Firebase Auth photo URL
/// (`harudiary-avatar://purple`), so it follows the account without a new diary field.
enum ProfileAvatar: String, CaseIterable, Equatable {
    case purple
    case violet
    case lavender
    case green
    case blue
    case orange
    case brown
    case pink

    /// Shown until the member picks one.
    static let `default` = ProfileAvatar.purple

    private static let scheme = "harudiary-avatar"

    var storedURL: String { "\(Self.scheme)://\(rawValue)" }

    /// Photo URLs set by Google or other apps are not avatars and fall back to the default.
    init?(storedURL: String?) {
        guard let storedURL, let url = URL(string: storedURL), url.scheme == Self.scheme,
              let host = url.host, let avatar = ProfileAvatar(rawValue: host) else { return nil }
        self = avatar
    }
}
