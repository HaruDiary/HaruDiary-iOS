import Foundation

/// Erases everything stored for a user: diary photos first, then the diary documents.
@MainActor
protocol UserDataErasing {
    func eraseAllData(userID: String) async throws
}

/// Order of an account deletion. Data is erased while the user can still access it,
/// and only then is the account deleted, so a withdrawn account leaves no diaries or photos behind.
enum AccountDeletion {
    /// Firebase asks for a sign-in within about five minutes before deleting an account. Starting only within
    /// three minutes leaves time for erasing, so data is rarely erased for an account that then cannot be deleted.
    static let recentSignInWindow: TimeInterval = 3 * 60

    /// - Parameter signedInFor: time since the last sign-in, measured on the server's clock.
    @MainActor
    static func run(signedInFor: TimeInterval?,
                    eraseData: () async throws -> Void,
                    deleteAccount: () async throws -> Void) async throws {
        guard let signedInFor, signedInFor < recentSignInWindow else {
            throw AccountDeletionError.requiresRecentLogin
        }
        do {
            try await eraseData()
        } catch {
            throw AccountDeletionError.dataErasureFailed
        }
        do {
            try await deleteAccount()
        } catch AccountDeletionError.requiresRecentLogin {
            // Erasing took longer than Firebase allows. Signing in again and retrying finishes the deletion.
            throw AccountDeletionError.dataErasedNeedsRecentLogin
        }
    }
}
