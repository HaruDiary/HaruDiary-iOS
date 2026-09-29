import Foundation

/// The profile picture a member picks. Stored as the Firebase Auth photo URL
/// (`harudiary-avatar://purple`), so it follows the account without a new diary field.
enum ProfileAvatar: String, CaseIterable, Equatable {
    // The original Google/Apple sign-in pictures, then color variants of the same drawing.
    case google
    case apple
    case lavender
    case mint
    case peach
    case pink
    case sky
    case violet

    /// Shown until the member picks a picture: the picture of the sign-in method, as before.
    static func `default`(for provider: SocialProvider?) -> ProfileAvatar {
        provider == .apple ? .apple : .google
    }

    private static let scheme = "harudiary-avatar"

    var storedURL: String { "\(Self.scheme)://\(rawValue)" }

    /// Photo URLs set by Google or other apps are not avatars and fall back to the default.
    init?(storedURL: String?) {
        guard let storedURL, let url = URL(string: storedURL), url.scheme == Self.scheme,
              let id = url.host, let avatar = ProfileAvatar(rawValue: id) ?? Self.previousIDs[id] else { return nil }
        self = avatar
    }

    // IDs saved by earlier test builds; kept readable so a chosen picture is not reset.
    private static let previousIDs: [String: ProfileAvatar] = [
        "purple": .violet, "blue": .apple, "green": .google, "orange": .peach, "brown": .peach,
        "moon": .violet, "sparkles": .lavender, "book": .violet, "leaf": .google,
        "cloud": .sky, "sun": .peach, "cup": .peach, "heart": .pink,
    ]
}
