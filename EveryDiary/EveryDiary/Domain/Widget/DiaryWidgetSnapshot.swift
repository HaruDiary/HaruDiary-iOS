import Foundation

/// What the home screen widget is given: only the days a diary was written, never a title or any writing.
/// The app writes it for the signed-in user; the widget works out today and this month from it by itself,
/// so it stays right after midnight without the app running.
struct DiaryWidgetSnapshot: Codable, Equatable {
    /// Days with at least one diary, as numbers like 20261001, oldest first.
    var writtenDays: [Int]
    /// Whose days these are. The widget does not show it; the app uses it to drop another account's days.
    var userID: String?

    static let empty = DiaryWidgetSnapshot(writtenDays: [])
    /// How far back days are kept: enough for the last week and the whole current month.
    static let keptDays = 62

    init(writtenDays: [Int], userID: String? = nil) {
        self.writtenDays = writtenDays
        self.userID = userID
    }

    static func key(for date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    /// What the widget shows on `date`.
    func status(on date: Date, calendar: Calendar) -> DiaryWidgetStatus {
        let written = Set(writtenDays)
        let today = calendar.startOfDay(for: date)
        let month = calendar.component(.month, from: today)
        let monthPrefix = Self.key(for: today, calendar: calendar) / 100
        let week = (0..<7).reversed().compactMap { back -> DiaryWidgetStatus.Day? in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            return DiaryWidgetStatus.Day(day: calendar.component(.day, from: day),
                                         weekday: calendar.component(.weekday, from: day),
                                         isWritten: written.contains(Self.key(for: day, calendar: calendar)),
                                         isToday: back == 0)
        }
        return DiaryWidgetStatus(
            wroteToday: written.contains(Self.key(for: today, calendar: calendar)),
            month: month,
            daysWrittenThisMonth: written.filter { $0 / 100 == monthPrefix }.count,
            daysInMonth: calendar.range(of: .day, in: .month, for: today)?.count ?? 30,
            week: week
        )
    }
}

struct DiaryWidgetStatus: Equatable {
    struct Day: Equatable, Identifiable {
        let day: Int
        /// 1 = Sunday … 7 = Saturday.
        let weekday: Int
        let isWritten: Bool
        let isToday: Bool
        var id: Int { day * 10 + weekday }
    }

    let wroteToday: Bool
    let month: Int
    let daysWrittenThisMonth: Int
    let daysInMonth: Int
    /// The last seven days, oldest first, ending today.
    let week: [Day]
}

/// Shared by the app and its widget.
enum DiaryWidgetShared {
    static let appGroup = "group.com.HexaDiary.EveryDiary"
    static let widgetKind = "DiaryStatusWidget"
}

protocol DiaryWidgetSnapshotStoring {
    func load() -> DiaryWidgetSnapshot
    func save(_ snapshot: DiaryWidgetSnapshot)
}
