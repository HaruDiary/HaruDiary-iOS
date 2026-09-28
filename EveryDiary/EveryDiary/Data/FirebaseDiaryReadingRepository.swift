import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseDiaryReadingRepository: DiaryReadingRepository {
    private let database: Firestore

    init(database: Firestore) {
        self.database = database
    }

    func observeDiaries(userID: String) -> AsyncThrowingStream<[DiaryEntry], Error> {
        let query = database.collection("users").document(userID).collection("diaries")
            .order(by: "dateString", descending: true)
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.finish(throwing: CalendarDataError.missingSnapshot)
                    return
                }
                // A malformed document is skipped instead of failing the whole subscription.
                let result = DiaryDocumentDecoding.decode(snapshot.documents, documentID: \.documentID) {
                    try $0.data(as: DiaryEntry.self)
                }
                if result.skippedCount > 0 {
                    // Counts only: document contents and IDs stay out of the log.
                    print("Skipped \(result.skippedCount) diary document(s) that could not be decoded")
                }
                continuation.yield(result.entries)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}

@MainActor
final class FirebaseDiaryUserSession: DiaryUserSession {
    private let auth: Auth

    init(auth: Auth) {
        self.auth = auth
    }

    func observeUserIDs() -> AsyncStream<String?> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user?.uid)
            }
            continuation.onTermination = { [auth] _ in auth.removeStateDidChangeListener(handle) }
        }
    }
}

private enum CalendarDataError: Error {
    case missingSnapshot
}
