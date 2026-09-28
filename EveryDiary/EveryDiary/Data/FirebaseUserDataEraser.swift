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

    /// Another device signed in to the same account can still save while this runs, so passes repeat until
    /// a fresh read finds nothing. Data that keeps appearing stops the deletion and the account is kept.
    func eraseAllData(userID: String) async throws {
        for _ in 0..<3 {
            if try await erasePass(userID: userID) == 0 { return }
        }
        throw UserDataErasureError.dataKeepsAppearing
    }

    /// Files uploaded to the user's folder but never saved in a diary (e.g. an interrupted save).
    /// A network or other failure stops the deletion so it can be retried with the account kept.
    /// Only when Storage rules deny listing does it continue with the photos the diaries reference;
    /// files left that way are found and removed by `scripts/admin/withdrawn-account-data.mjs`.
    private func listUserFolder(_ userID: String) async throws -> [StorageReference] {
        do {
            return try await storage.reference().child(userID).listAll().items
        } catch let error as NSError where error.domain == StorageErrorDomain && error.code == StorageErrorCode.unauthorized.rawValue {
            print("Listing the user's photo folder is not allowed; erasing the photos saved in diaries only")
            return []
        }
    }

    /// Returns how many diaries and photo files were found (and erased) in this pass.
    private func erasePass(userID: String) async throws -> Int {
        // From the server, so diaries missing from the local cache are not left behind.
        let diaries = try await database.collection("users").document(userID).collection("diaries").getDocuments(source: .server)
        let folderItems = try await listUserFolder(userID)

        // Photos first: if one fails, the diaries that point to it remain and the deletion can be retried.
        var failedCount = 0
        let photoURLs = Set(diaries.documents.flatMap { $0.data()["imageURL"] as? [String] ?? [] })
        for url in photoURLs where !(await FirebasePhotoFiles.delete(urlString: url)) {
            failedCount += 1
        }
        for item in folderItems {
            do {
                try await item.delete()
            } catch {
                if !FirebasePhotoFiles.isMissingObject(error) { failedCount += 1 }
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
        let found = references.count + photoURLs.count + folderItems.count
        if found > 0 {
            print("Erased account data: \(references.count) diaries, \(photoURLs.count + folderItems.count) photo files")
        }
        return found
    }
}

enum UserDataErasureError: Error {
    case photosRemaining(count: Int)
    case dataKeepsAppearing
}
