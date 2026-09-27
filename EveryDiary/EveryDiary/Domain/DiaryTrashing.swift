import Foundation

@MainActor
protocol DiaryTrashing {
    /// Marks `users/{userID}/diaries/{diaryID}` as deleted. Only `isDeleted` and `deleteDate` change,
    /// and the call fails when that user has no such document, so it can never write into another account.
    func moveToTrash(diaryID: String, userID: String, at date: Date) async throws
}
