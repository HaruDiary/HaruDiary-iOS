import Foundation

/// How a date is marked in date labels: Saturday blue, Sunday and public holidays red.
enum DayKind: Equatable {
    case weekday
    case saturday
    case holiday

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            self = .weekday
            return
        }
        // Gregorian weekday numbering: 1 = Sunday, 7 = Saturday.
        if components.weekday == 1 || KoreanPublicHolidays.contains(year: year, month: month, day: day) {
            self = .holiday
        } else if components.weekday == 7 {
            self = .saturday
        } else {
            self = .weekday
        }
    }
}

/// Official Korean public holidays, including substitute and temporary holidays.
///
/// Lunar holidays, substitute rules and temporary holidays (elections, one-off days) cannot be derived
/// reliably — e.g. Foundation's Chinese calendar puts Seollal 2027 on Feb 6 while Korea observes Feb 7 —
/// so dates come from the announced lists. Years outside `coveredYears` show weekends only.
/// Add the next year once the government announces it.
enum KoreanPublicHolidays {
    static var coveredYears: ClosedRange<Int> { 2024...2027 }

    static func contains(year: Int, month: Int, day: Int) -> Bool {
        dates[year]?.contains(month * 100 + day) ?? false
    }

    // MMDD per year.
    private static let dates: [Int: Set<Int>] = [
        2024: [101, 209, 210, 211, 212, 301, 410, 505, 506, 515, 606, 815, 916, 917, 918, 1001, 1003, 1009, 1225],
        2025: [101, 127, 128, 129, 130, 301, 303, 505, 506, 603, 606, 815, 1003, 1005, 1006, 1007, 1008, 1009, 1225],
        2026: [101, 216, 217, 218, 301, 302, 501, 505, 524, 525, 603, 606, 717, 815, 817, 924, 925, 926, 1003, 1005, 1009, 1225],
        2027: [101, 206, 207, 208, 209, 301, 501, 503, 505, 513, 606, 717, 719, 815, 816, 914, 915, 916, 1003, 1004, 1009, 1011, 1225, 1227],
    ]
}
