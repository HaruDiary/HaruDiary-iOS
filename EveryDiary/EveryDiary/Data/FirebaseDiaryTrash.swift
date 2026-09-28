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

    func deletePermanently(diaryID: String, userID: String, imageURLs: [String], condition: PermanentDeletionCondition) async throws -> PhotoCleanup {
        let reference = document(diaryID, userID)
        guard Self.matches(try await reference.getDocument().data(), condition) else {
            throw DiaryTrashError.conditionNotMet
        }
        var cleanup = PhotoCleanup()
        var failedCount = 0
        for url in imageURLs {
            let error = await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
                FirebaseStorageManager.deleteImage(urlString: url) { continuation.resume(returning: $0) }
            }
            if let error, !Self.isMissingObject(error) { failedCount += 1 } else { cleanup.deletedCount += 1 }
        }
        guard failedCount == 0 else { throw DiaryTrashError.photoCleanupFailed(failedCount: failedCount) }
        // Re-checked inside the transaction so a restore saved while photos were being removed wins.
        _ = try await database.runTransaction { transaction, errorPointer in
            do {
                guard Self.matches(try transaction.getDocument(reference).data(), condition) else {
                    errorPointer?.pointee = DiaryTrashError.conditionNotMet as NSError
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

    nonisolated private static func matches(_ data: [String: Any]?, _ condition: PermanentDeletionCondition) -> Bool {
        guard let data, data["isDeleted"] as? Bool == true else { return false }
        switch condition {
        case .inTrash:
            return true
        case .expired(let expected):
            let stored = (data["deleteDate"] as? Timestamp)?.dateValue()
            switch (stored, expected) {
            case (nil, nil): return true
            case let (stored?, expected?): return abs(stored.timeIntervalSince(expected)) < 0.001
            default: return false
            }
        }
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
