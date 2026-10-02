import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseUserDirectory: UserDirectoryWriting {
    private let database: Firestore

    init(database: Firestore) {
        self.database = database
    }

    /// Merged, so nothing else in the document is touched. A nickname or e-mail the account no longer has is removed.
    func write(_ entry: UserDirectoryEntry, userID: String, seenAt: Date) async throws {
        let fields: [String: Any] = [
            "supportCode": entry.supportCode,
            "nickname": entry.nickname.map { $0 as Any } ?? FieldValue.delete(),
            "provider": entry.provider,
            "email": entry.email.map { $0 as Any } ?? FieldValue.delete(),
            "lastSeenAt": Timestamp(date: seenAt),
        ]
        try await database.collection("users").document(userID).setData(fields, merge: true)
    }
}
