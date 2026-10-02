import Foundation

/// A short code a user can read out when asking for help. It is the start of the account's ID, so it needs
/// no issuing, is the same on every device, and exists for every account: Google, Apple and guests alike.
enum SupportCode {
    static let length = 8

    /// "A3F927KD…" becomes "A3F9-27KD". Nil when the ID is too short to make a code from.
    static func make(userID: String) -> String? {
        let characters = userID.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        guard characters.count >= length else { return nil }
        let code = String(characters.prefix(length))
        return code.prefix(4) + "-" + code.suffix(4)
    }
}

/// What `users/{userID}` says about an account, so the people running the service can tell accounts apart:
/// by the support code (every account), the nickname, or the e-mail where there is one.
/// Apple accounts may carry a relay address or none at all; that is why the code exists.
struct UserDirectoryEntry: Equatable {
    let supportCode: String
    let nickname: String?
    /// "google", "apple", "guest", or "other" for a verified account without Google or Apple.
    let provider: String
    let email: String?

    /// Nil when the account has no ID yet.
    init?(_ snapshot: AccountSnapshot) {
        guard let userID = snapshot.userID, let supportCode = SupportCode.make(userID: userID) else { return nil }
        self.supportCode = supportCode
        nickname = snapshot.displayName
        email = snapshot.email
        switch AccountState(snapshot) {
        case .member(_, _, .google): provider = "google"
        case .member(_, _, .apple): provider = "apple"
        case .member: provider = "other"
        case .guest, .signedOut: provider = "guest"
        }
    }
}

@MainActor
protocol UserDirectoryWriting {
    /// Writes the entry into `users/{userID}` next to the diaries, leaving everything else there as it is.
    func write(_ entry: UserDirectoryEntry, userID: String, seenAt: Date) async throws
}

/// What was last written, kept so an unchanged entry is written once a day at most.
protocol UserDirectoryRecordStoring {
    func lastWritten(userID: String) -> String?
    func setLastWritten(_ record: String, userID: String)
}

/// Stops the writing of an account's entry while the account is being withdrawn.
@MainActor
protocol UserDirectorySuspending: AnyObject {
    func suspendWrites(userID: String)
    func resumeWrites(userID: String)
}

enum UserDirectoryError: Error {
    /// The account is being withdrawn; its entry must not be written back.
    case suspended
}

/// A directory whose writes can be stopped per account. A withdrawal deletes `users/{userID}`; a write arriving
/// after that would put the support code, nickname and e-mail back for an account that is gone.
@MainActor
final class SuspendableUserDirectory: UserDirectoryWriting, UserDirectorySuspending {
    private let directory: any UserDirectoryWriting
    private var suspended: Set<String> = []

    init(_ directory: any UserDirectoryWriting) {
        self.directory = directory
    }

    func write(_ entry: UserDirectoryEntry, userID: String, seenAt: Date) async throws {
        guard !suspended.contains(userID) else { throw UserDirectoryError.suspended }
        try await directory.write(entry, userID: userID, seenAt: seenAt)
    }

    func suspendWrites(userID: String) {
        suspended.insert(userID)
    }

    func resumeWrites(userID: String) {
        suspended.remove(userID)
    }
}
