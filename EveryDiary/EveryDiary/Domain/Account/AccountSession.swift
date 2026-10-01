import Foundation

/// Sign-out and account deletion for the signed-in user.
@MainActor
protocol AccountSession {
    /// The account as it is right now, so a screen can show it before the first observed value arrives.
    var currentAccount: AccountSnapshot? { get }
    /// Emits the current account first, then again after sign-in, sign-out or a profile change.
    func observeAccount() -> AsyncStream<AccountSnapshot?>
    func signOut() throws
    /// Saves the nickname and picture shown in settings (Firebase Auth display name and photo URL;
    /// no diary data changes). A new photo is uploaded first, the profile is changed next, and the
    /// previous uploaded photo is removed last; on failure the previous profile stays.
    /// Returns the picture now on the profile.
    func updateProfile(nickname: String, picture: ProfilePictureSelection) async throws -> ProfilePicture
    /// Erases the user's diaries and photos, then deletes the signed-in Google/Apple account.
    /// Apple members pass a fresh Sign in with Apple result: it confirms the member and lets Firebase
    /// revoke the Apple token before anything is erased.
    func deleteAccount(appleAuthorization: AppleAuthorization?) async throws
}

enum AccountDeletionError: Error, Equatable {
    case notSignedIn
    /// Only Google and Apple accounts can be deleted from settings.
    case unsupportedAccount
    /// Firebase requires a recent sign-in before an account can be deleted.
    case requiresRecentLogin
    /// Some diaries or photos could not be erased, so the account was kept and deletion can be retried.
    case dataErasureFailed
    /// Diaries and photos were erased, but the account needs a new sign-in before it can be deleted.
    case dataErasedNeedsRecentLogin
    /// An Apple member must confirm with Sign in with Apple (the same Apple ID) before deleting.
    case appleConfirmationRequired
    /// Firebase could not revoke the Apple token; nothing was erased.
    case appleRevocationFailed
}
