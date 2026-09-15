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
                do {
                    let entries = try snapshot.documents.map { document in
                        var entry = try document.data(as: DiaryEntry.self)
                        // Navigation uses the existing document identity, including legacy records without an id field.
                        entry.id = document.documentID
                        return entry
                    }
                    continuation.yield(entries)
                } catch {
                    continuation.finish(throwing: error)
                }
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
