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

    func deletePermanently(diaryID: String, userID: String, imageURLs: [String]) async throws -> PhotoCleanup {
        try await document(diaryID, userID).delete()
        var cleanup = PhotoCleanup()
        for url in imageURLs {
            let failed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                FirebaseStorageManager.deleteImage(urlString: url) { error in continuation.resume(returning: error != nil) }
            }
            if failed { cleanup.failedCount += 1 } else { cleanup.deletedCount += 1 }
        }
        return cleanup
    }

    private func document(_ diaryID: String, _ userID: String) -> DocumentReference {
        database.collection("users").document(userID).collection("diaries").document(diaryID)
    }
}
