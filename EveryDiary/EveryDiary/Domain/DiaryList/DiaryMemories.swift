import Foundation

/// Diaries written on today's date in an earlier year ("1년 전 오늘").
struct DiaryMemory: Identifiable {
    let yearsAgo: Int
    /// Newest first, like the list.
    let entries: [DiaryEntry]
    var id: Int { yearsAgo }
}

enum DiaryMemories {
    /// The most recent year first. February 29 is only met again on a February 29.
    static func onThisDay(from entries: [DiaryEntry], today: Date, calendar: Calendar) -> [DiaryMemory] {
        let now = calendar.dateComponents([.year, .month, .day], from: today)
        guard let year = now.year else { return [] }
        var byYearsAgo: [Int: [(entry: DiaryEntry, date: Date)]] = [:]
        for entry in entries where !entry.isDeleted {
            // Like the list, a diary whose stored date cannot be read is left out.
            guard let date = DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString) else { continue }
            let written = calendar.dateComponents([.year, .month, .day], from: date)
            guard written.month == now.month, written.day == now.day, let writtenYear = written.year, writtenYear < year else { continue }
            byYearsAgo[year - writtenYear, default: []].append((entry, date))
        }
        return byYearsAgo.keys.sorted().map { yearsAgo in
            let sorted = byYearsAgo[yearsAgo, default: []].sorted { lhs, rhs in
                lhs.date == rhs.date ? (lhs.entry.id ?? "") < (rhs.entry.id ?? "") : lhs.date > rhs.date
            }
            return DiaryMemory(yearsAgo: yearsAgo, entries: sorted.map(\.entry))
        }
    }
}
