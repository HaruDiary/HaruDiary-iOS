import FirebaseFirestore
import FirebaseStorage
import Foundation

/// Erases `users/{userID}/diaries` and the photos under the user's Storage folder.
@MainActor
final class FirebaseUserDataEraser: UserDataErasing {
    private let database: Firestore
    private let storage: Storage

    init(database: Firestore, storage: Storage) {
        self.database = database
        self.storage = storage
    }

    func eraseAllData(userID: String) async throws {
        // From the server, so diaries missing from the local cache are not left behind.
        let diaries = try await database.collection("users").document(userID).collection("diaries").getDocuments(source: .server)

        // Photos first: if one fails, the diaries that point to it remain and the deletion can be retried.
        var failedCount = 0
        let photoURLs = Set(diaries.documents.flatMap { $0.data()["imageURL"] as? [String] ?? [] })
        for url in photoURLs where !(await FirebasePhotoFiles.delete(urlString: url)) {
            failedCount += 1
        }
        // Files uploaded to the user's folder but never saved in a diary (e.g. an interrupted save).
        // Listing may be denied by Storage rules; the referenced photos above are still removed.
        if let folder = try? await storage.reference().child(userID).listAll() {
            for item in folder.items {
                do {
                    try await item.delete()
                } catch {
                    if !FirebasePhotoFiles.isMissingObject(error) { failedCount += 1 }
                }
            }
        }
        guard failedCount == 0 else { throw UserDataErasureError.photosRemaining(count: failedCount) }

        // A Firestore batch holds at most 500 writes.
        let references = diaries.documents.map(\.reference)
        for start in stride(from: 0, to: references.count, by: 400) {
            let batch = database.batch()
            references[start..<min(start + 400, references.count)].forEach { batch.deleteDocument($0) }
            try await batch.commit()
        }
        print("Erased account data: \(references.count) diaries, \(photoURLs.count) photos")
    }
}

enum UserDataErasureError: Error {
    case photosRemaining(count: Int)
}
