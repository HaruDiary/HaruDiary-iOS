import Foundation

/// One month of the journey: the days with at least one diary. Each day lights one building window.
struct JourneyMonth: Equatable {
    let year: Int
    let month: Int
    let days: Set<Int>

    /// "yyyy.MM", the section title and key the honor screen has always shown.
    var title: String {
        String(format: "%04d.%02d", year, month)
    }
}

/// Diary days grouped by month, built from the shared diary feed without UIKit or Firebase.
struct JourneyRecord: Equatable {
    /// Newest month first. Months without a diary are left out.
    let months: [JourneyMonth]

    static let empty = JourneyRecord(months: [])

    private init(months: [JourneyMonth]) {
        self.months = months
    }

    /// Trashed diaries and diaries whose date cannot be read light no window.
    init(entries: [DiaryEntry], calendar: Calendar) {
        var daysByMonth: [MonthKey: Set<Int>] = [:]
        for entry in entries where !entry.isDeleted {
            guard let date = DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString) else { continue }
            let key = MonthKey(year: calendar.component(.year, from: date), month: calendar.component(.month, from: date))
            daysByMonth[key, default: []].insert(calendar.component(.day, from: date))
        }
        months = daysByMonth
            .map { JourneyMonth(year: $0.key.year, month: $0.key.month, days: $0.value) }
            .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }

    /// The month containing `date`; a month without diaries has no days.
    func month(containing date: Date, calendar: Calendar) -> JourneyMonth {
        month(year: calendar.component(.year, from: date), month: calendar.component(.month, from: date))
    }

    func month(year: Int, month: Int) -> JourneyMonth {
        months.first { $0.year == year && $0.month == month } ?? JourneyMonth(year: year, month: month, days: [])
    }

    private struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }
}
