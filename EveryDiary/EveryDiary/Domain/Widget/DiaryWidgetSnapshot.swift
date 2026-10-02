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
        let wroteToday = written.contains(Self.key(for: today, calendar: calendar))
        return DiaryWidgetStatus(
            wroteToday: wroteToday,
            month: month,
            day: calendar.component(.day, from: today),
            weekday: calendar.component(.weekday, from: today),
            phrase: DiaryWidgetPhrases.phrase(wroteToday: wroteToday, at: date, calendar: calendar),
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
    /// Today's day of the month and weekday (1 = Sunday … 7 = Saturday).
    let day: Int
    let weekday: Int
    /// A short line that goes with today's state; it changes a few times a day.
    let phrase: String
    let daysWrittenThisMonth: Int
    let daysInMonth: Int
    /// The last seven days, oldest first, ending today.
    let week: [Day]
}

/// The lines the widget shows: some invite writing, the others follow a day already written.
/// Which one is shown looks random but follows from the time, so the widget and its tests agree and
/// a redraw at the same hour does not make the line jump.
enum DiaryWidgetPhrases {
    static let notWritten = [
        "오늘 하루는 어땠나요?",
        "한 줄이면 충분해요.",
        "오늘의 나를 남겨 볼까요?",
        "지금 떠오르는 생각을 적어 보세요.",
        "사소한 하루도 기록하면 특별해져요.",
        "오늘 가장 기억에 남는 순간은요?",
        "잠깐 멈추고 오늘을 돌아봐요.",
        "오늘의 기분을 한 단어로 남겨요.",
        "내일의 나에게 오늘을 전해 주세요.",
        "쓰다 보면 마음이 가벼워져요.",
        "오늘 고마웠던 일이 있었나요?",
        "지나가면 잊히는 하루, 붙잡아 둘까요?",
    ]

    static let written = [
        "오늘도 하루를 남겼어요.",
        "오늘의 기록, 잘 간직할게요.",
        "하루를 돌아본 당신, 멋져요.",
        "오늘의 이야기가 쌓였어요.",
        "내일도 여기서 만나요.",
        "기록한 하루는 오래 남아요.",
        "오늘의 불이 켜졌어요.",
        "차곡차곡 쌓이는 중이에요.",
        "수고한 오늘, 편히 쉬어요.",
        "오늘의 나를 기억할게요.",
        "한 걸음 더 나아갔어요.",
        "오늘도 여정이 이어졌어요.",
    ]

    /// How often the line changes.
    static let hoursPerPhrase = 6

    /// The start of each stretch of a day in which one line is shown; the widget is redrawn at these times.
    static func changeTimes(onDayOf date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.startOfDay(for: date)
        return stride(from: 0, to: 24, by: hoursPerPhrase).compactMap { calendar.date(byAdding: .hour, value: $0, to: start) }
    }

    static func phrase(wroteToday: Bool, at date: Date, calendar: Calendar) -> String {
        let phrases = wroteToday ? written : notWritten
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let slot = calendar.component(.hour, from: date) / hoursPerPhrase
        // Mixed, so one line is not simply followed by the next in the list.
        var mixed = UInt64(truncatingIfNeeded: day &* 4 &+ slot) &* 0x9E37_79B9_7F4A_7C15
        mixed ^= mixed >> 29
        mixed = mixed &* 0xBF58_476D_1CE4_E5B9
        mixed ^= mixed >> 32
        return phrases[Int(mixed % UInt64(phrases.count))]
    }
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
