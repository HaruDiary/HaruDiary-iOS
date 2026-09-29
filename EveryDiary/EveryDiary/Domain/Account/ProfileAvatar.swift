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
              let id = url.host, let avatar = ProfileAvatar(rawValue: id) ?? Self.previousIDs[id] else { return nil }
        self = avatar
    }

    // IDs saved by the earlier icon set; kept readable so a chosen picture is not reset.
    private static let previousIDs: [String: ProfileAvatar] = [
        "moon": .purple, "sparkles": .violet, "book": .lavender, "leaf": .green,
        "cloud": .blue, "sun": .orange, "cup": .brown, "heart": .pink,
    ]
}
