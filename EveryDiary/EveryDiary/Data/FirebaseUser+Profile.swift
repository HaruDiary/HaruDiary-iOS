import FirebaseAuth
import Foundation

// A guest that links Google/Apple may keep no e-mail or name on the account itself;
// the linked sign-in still carries them, so those are used instead.
extension User {
    var shownEmail: String? {
        Self.nonEmpty(email) ?? providerData.lazy.compactMap { Self.nonEmpty($0.email) }.first
    }

    var shownName: String? {
        Self.nonEmpty(displayName) ?? providerData.lazy.compactMap { Self.nonEmpty($0.displayName) }.first
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
