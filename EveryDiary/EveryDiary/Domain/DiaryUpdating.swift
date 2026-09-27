import Foundation

@MainActor
protocol DiaryUpdating {
    /// Replaces the stored diary document identified by `entry.id` with `entry`.
    func update(_ entry: DiaryEntry) async throws
}

extension DiaryEntry {
    func movedToTrash(at date: Date) -> DiaryEntry {
        var entry = self
        entry.isDeleted = true
        entry.deleteDate = date
        return entry
    }
}
