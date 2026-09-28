import Foundation

/// Trash operations on `users/{userID}/diaries/{diaryID}`, always bound to the user who asked.
@MainActor
protocol DiaryTrashing {
    /// Marks the diary as deleted. Only `isDeleted` and `deleteDate` change,
    /// and the call fails when that user has no such document, so it can never write into another account.
    func moveToTrash(diaryID: String, userID: String, at date: Date) async throws

    /// Brings the diary back to the list. Only `isDeleted` and `deleteDate` change.
    func restore(diaryID: String, userID: String) async throws

    /// Deletes the photo files first and the diary document only when every photo is gone.
    /// When a photo fails, the call throws and the diary stays in the trash so deleting can be retried;
    /// photos that are already gone count as deleted, so a retry finishes the rest.
    /// The stored document is checked against `condition` before the photos and again when the document is deleted,
    /// so a diary restored (or trashed again) on another device is not removed.
    @discardableResult
    func deletePermanently(diaryID: String, userID: String, imageURLs: [String], condition: PermanentDeletionCondition) async throws -> PhotoCleanup
}

enum PermanentDeletionCondition: Equatable {
    /// The user asked: delete while the diary is still in the trash.
    case inTrash
    /// Retention ended: delete only while it is still in the trash with the `deleteDate` that was judged expired.
    case expired(deleteDate: Date?)
}

struct PhotoCleanup: Equatable {
    var deletedCount = 0
}

enum DiaryTrashError: Error, Equatable {
    /// Some photo files could not be deleted, so the diary document was kept.
    case photoCleanupFailed(failedCount: Int)
    /// The stored diary no longer matches the deletion condition, e.g. it was restored on another device.
    case conditionNotMet
}
