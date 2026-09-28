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
    /// Deletes only while the stored diary is still in the trash with the `deleteDate` the caller saw.
    /// It is checked before the photos and again when the document is deleted, so a diary restored
    /// (or restored and trashed again) on another device is not removed.
    @discardableResult
    func deletePermanently(diaryID: String, userID: String, imageURLs: [String], trashedAt deleteDate: Date?) async throws -> PhotoCleanup
}

struct PhotoCleanup: Equatable {
    var deletedCount = 0
}

enum DiaryTrashError: Error, Equatable {
    /// Some photo files could not be deleted, so the diary document was kept.
    case photoCleanupFailed(failedCount: Int)
    /// The stored diary is no longer the trashed diary the caller saw, e.g. it was restored on another device.
    case trashStateChanged
}
