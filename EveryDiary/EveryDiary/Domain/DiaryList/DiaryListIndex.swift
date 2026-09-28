import Foundation

struct DiaryListSection: Identifiable {
    let year: Int
    let month: Int
    let entries: [DiaryEntry]

    // Same text as the legacy month header ("yyyy.MM").
    var id: String { String(format: "%04d.%02d", year, month) }
}

enum DiaryListScope {
    /// Diaries shown in the main list.
    case active
    /// Diaries in the trash.
    case trash
}

enum DiaryListIndex {
    static func normalizedQuery(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Groups visible diaries by month, newest month and newest diary first.
    static func sections(from entries: [DiaryEntry], matching query: String = "", calendar: Calendar,
                         scope: DiaryListScope = .active) -> [DiaryListSection] {
        let query = normalizedQuery(query)
        let datedEntries = entries.compactMap { entry -> (entry: DiaryEntry, date: Date)? in
            // The list has always hidden records whose stored date cannot be parsed.
            guard entry.isDeleted == (scope == .trash), matches(entry, query: query),
                  let date = DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString) else { return nil }
            return (entry, date)
        }.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return (lhs.entry.id ?? "") < (rhs.entry.id ?? "")
            }
            return lhs.date > rhs.date
        }

        var sections: [(year: Int, month: Int, entries: [DiaryEntry])] = []
        for item in datedEntries {
            let year = calendar.component(.year, from: item.date)
            let month = calendar.component(.month, from: item.date)
            if let last = sections.last, last.year == year, last.month == month {
                sections[sections.count - 1].entries.append(item.entry)
            } else {
                sections.append((year, month, [item.entry]))
            }
        }
        return sections.map { DiaryListSection(year: $0.year, month: $0.month, entries: $0.entries) }
    }

    static func matches(_ entry: DiaryEntry, query: String) -> Bool {
        query.isEmpty
            || entry.title.localizedCaseInsensitiveContains(query)
            || entry.content.localizedCaseInsensitiveContains(query)
    }
}
