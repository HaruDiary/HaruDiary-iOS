import FirebaseFirestore
import FirebaseStorage
import Foundation

@MainActor
final class FirebaseDiaryTrash: DiaryTrashing {
    private let database: Firestore

    init(database: Firestore) {
        self.database = database
    }

    func moveToTrash(diaryID: String, userID: String, at date: Date) async throws {
        // Same path and Date → Timestamp encoding as DiaryManager, but bound to the requesting user
        // (not Auth.currentUser at write time) and limited to the trash fields.
        try await document(diaryID, userID).updateData(["isDeleted": true, "deleteDate": Timestamp(date: date)])
    }

    func restore(diaryID: String, userID: String) async throws {
        try await document(diaryID, userID).updateData(["isDeleted": false, "deleteDate": FieldValue.delete()])
    }

    func deletePermanently(diaryID: String, userID: String, imageURLs: [String]) async throws -> PhotoCleanup {
        var cleanup = PhotoCleanup()
        var failedCount = 0
        for url in imageURLs {
            let error = await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
                FirebaseStorageManager.deleteImage(urlString: url) { continuation.resume(returning: $0) }
            }
            if let error, !Self.isMissingObject(error) { failedCount += 1 } else { cleanup.deletedCount += 1 }
        }
        guard failedCount == 0 else { throw DiaryTrashError.photoCleanupFailed(failedCount: failedCount) }
        try await document(diaryID, userID).delete()
        return cleanup
    }

    // A photo removed by an earlier, partly failed attempt is already done.
    private static func isMissingObject(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == StorageErrorDomain && error.code == StorageErrorCode.objectNotFound.rawValue
    }

    private func document(_ diaryID: String, _ userID: String) -> DocumentReference {
        database.collection("users").document(userID).collection("diaries").document(diaryID)
    }
}
