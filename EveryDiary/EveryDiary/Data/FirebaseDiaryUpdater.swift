import Foundation

/// Uses the existing `DiaryManager` write so the stored path and fields stay identical.
@MainActor
final class FirebaseDiaryUpdater: DiaryUpdating {
    enum UpdateError: Error {
        case missingDocumentID
    }

    private let manager: DiaryManager

    init(manager: DiaryManager) {
        self.manager = manager
    }

    func update(_ entry: DiaryEntry) async throws {
        guard let diaryID = entry.id else { throw UpdateError.missingDocumentID }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.updateDiary(diaryID: diaryID, newDiary: entry) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
