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
        try await database.collection("users").document(userID).collection("diaries").document(diaryID)
            .updateData(["isDeleted": true, "deleteDate": Timestamp(date: date)])
    }
}
