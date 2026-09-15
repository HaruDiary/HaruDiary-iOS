import Foundation

struct CalendarDay: Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(date: Date, calendar: Calendar) {
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
        day = calendar.component(.day, from: date)
    }

    var dateComponents: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }
}

struct CalendarDiaryIndex {
    private let groupedEntries: [CalendarDay: [DiaryEntry]]

    init(entries: [DiaryEntry], calendar: Calendar, now: Date) {
        let datedEntries = entries.filter { !$0.isDeleted }.map { entry in
            (entry: entry, date: DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString) ?? now)
        }.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return (lhs.entry.id ?? "") < (rhs.entry.id ?? "")
            }
            return lhs.date > rhs.date
        }
        groupedEntries = Dictionary(grouping: datedEntries) {
            CalendarDay(date: $0.date, calendar: calendar)
        }.mapValues { $0.map(\.entry) }
    }

    func entries(on day: CalendarDay) -> [DiaryEntry] {
        groupedEntries[day] ?? []
    }

    var decoratedDays: Set<CalendarDay> {
        Set(groupedEntries.keys)
    }

    func decorationDaysToReload(previous: Set<CalendarDay>) -> Set<CalendarDay> {
        previous.union(decoratedDays)
    }
}

struct CalendarMonth {
    let start: Date
    let cells: [Date?]

    init?(date: Date, calendar: Calendar) {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: date) else {
            return nil
        }
        let monthStart = interval.start
        let leadingCount = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let dates = dayRange.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: monthStart) }
        let trailingCount = (7 - (leadingCount + dates.count) % 7) % 7
        start = monthStart
        cells = Array(repeating: nil, count: leadingCount) + dates.map(Optional.some) + Array(repeating: nil, count: trailingCount)
    }
}
