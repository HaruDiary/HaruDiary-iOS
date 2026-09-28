import Foundation

/// Permanently deletes trashed diaries whose retention period has ended.
/// Runs on the device when the trash is observed; each diary is deleted at most once at a time.
@MainActor
final class ExpiredTrashPurger {
    struct Result: Equatable {
        var deletedCount = 0
        var failedCount = 0
    }

    private let trash: any DiaryTrashing
    private let calendar: Calendar
    private var inFlight: Set<String> = []

    init(trash: any DiaryTrashing, calendar: Calendar) {
        self.trash = trash
        self.calendar = calendar
    }

    func purgeExpired(in entries: [DiaryEntry], userID: String, now: Date) async -> Result {
        let expired = entries.filter { entry in
            guard let id = entry.id else { return false }
            return !inFlight.contains(id) && DiaryTrashPolicy.isExpired(entry, now: now, calendar: calendar)
        }
        var result = Result()
        for entry in expired {
            guard let id = entry.id else { continue }
            inFlight.insert(id)
            do {
                try await trash.deletePermanently(diaryID: id, userID: userID, imageURLs: entry.imageURL ?? [],
                                                  trashedAt: entry.deleteDate)
                result.deletedCount += 1
            } catch {
                result.failedCount += 1
            }
            inFlight.remove(id)
        }
        return result
    }
}
