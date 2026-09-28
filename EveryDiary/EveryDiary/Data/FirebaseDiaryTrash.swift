import FirebaseFirestore
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

    func deletePermanently(diaryID: String, userID: String, imageURLs: [String], trashedAt deleteDate: Date?) async throws -> PhotoCleanup {
        let reference = document(diaryID, userID)
        guard Self.isTrashed(try await reference.getDocument().data(), at: deleteDate) else {
            throw DiaryTrashError.trashStateChanged
        }
        var cleanup = PhotoCleanup()
        var failedCount = 0
        for url in imageURLs {
            if await FirebasePhotoFiles.delete(urlString: url) { cleanup.deletedCount += 1 } else { failedCount += 1 }
        }
        guard failedCount == 0 else { throw DiaryTrashError.photoCleanupFailed(failedCount: failedCount) }
        // Re-checked inside the transaction so a restore saved while photos were being removed wins.
        _ = try await database.runTransaction { transaction, errorPointer in
            do {
                guard Self.isTrashed(try transaction.getDocument(reference).data(), at: deleteDate) else {
                    errorPointer?.pointee = DiaryTrashError.trashStateChanged as NSError
                    return nil
                }
                transaction.deleteDocument(reference)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
        return cleanup
    }

    nonisolated private static func isTrashed(_ data: [String: Any]?, at expected: Date?) -> Bool {
        guard let data, data["isDeleted"] as? Bool == true else { return false }
        switch ((data["deleteDate"] as? Timestamp)?.dateValue(), expected) {
        case (nil, nil): return true
        case let (stored?, expected?): return abs(stored.timeIntervalSince(expected)) < 0.001
        default: return false
        }
    }

    private func document(_ diaryID: String, _ userID: String) -> DocumentReference {
        database.collection("users").document(userID).collection("diaries").document(diaryID)
    }
}
