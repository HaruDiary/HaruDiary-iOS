import Foundation

/// Apple's answer for whether this app may still use the member's Sign in with Apple.
enum AppleCredentialStatus: Equatable {
    case authorized
    /// The member stopped using Sign in with Apple for this app (Settings › Apple Account › Sign in with Apple).
    case revoked
    case notFound
    case transferred

    /// Only an explicit revocation signs the member out. `notFound` is also returned on simulators and
    /// transiently, so signing out on it would log out members who did nothing.
    var endsSession: Bool { self == .revoked }
}
