import Foundation

/// Erases everything stored for a user: diary photos first, then the diary documents.
@MainActor
protocol UserDataErasing {
    func eraseAllData(userID: String) async throws
}

/// Order of an account deletion. Data is erased while the user can still access it,
/// and only then is the account deleted, so a withdrawn account leaves no diaries or photos behind.
enum AccountDeletion {
    /// Firebase asks for a recent sign-in before deleting an account. Checking first means
    /// data is never erased for an account that then cannot be deleted.
    static let recentSignInWindow: TimeInterval = 5 * 60

    @MainActor
    static func run(lastSignIn: Date?, now: Date,
                    eraseData: () async throws -> Void,
                    deleteAccount: () async throws -> Void) async throws {
        guard let lastSignIn, now.timeIntervalSince(lastSignIn) < recentSignInWindow else {
            throw AccountDeletionError.requiresRecentLogin
        }
        do {
            try await eraseData()
        } catch {
            throw AccountDeletionError.dataErasureFailed
        }
        try await deleteAccount()
    }
}
