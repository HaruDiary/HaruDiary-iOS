import Foundation

/// How long a diary stays in the trash before it is permanently deleted.
enum DiaryTrashPolicy {
    static let retentionDays = 30

    /// 2026-09-28 00:00 KST, when the 30-day rule started. The previous auto-delete never ran,
    /// so diaries trashed before this date count from here instead of being deleted all at once
    /// on the first launch. Trashed diaries without a stored deleteDate use it too.
    static let effectiveDate = Date(timeIntervalSince1970: 1_790_521_200)

    static func deadline(for entry: DiaryEntry, calendar: Calendar) -> Date? {
        guard entry.isDeleted else { return nil }
        let start = max(entry.deleteDate ?? effectiveDate, effectiveDate)
        return calendar.date(byAdding: .day, value: retentionDays, to: start)
    }

    static func isExpired(_ entry: DiaryEntry, now: Date, calendar: Calendar) -> Bool {
        guard let deadline = deadline(for: entry, calendar: calendar) else { return false }
        return now >= deadline
    }

    /// Whole days left before permanent deletion, rounded up (a few hours left counts as 1 day).
    /// Nil for diaries that are not in the trash; 0 once the deadline has passed.
    static func daysRemaining(for entry: DiaryEntry, now: Date, calendar: Calendar) -> Int? {
        guard let deadline = deadline(for: entry, calendar: calendar) else { return nil }
        let seconds = deadline.timeIntervalSince(now)
        guard seconds > 0 else { return 0 }
        return Int((seconds / 86_400).rounded(.up))
    }
}
