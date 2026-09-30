import Foundation

/// When to remind the user to write. Weekdays follow `Calendar`: 1 = Sunday … 7 = Saturday.
struct ReminderSettings: Equatable {
    var isOn = false
    var hour = 21
    var minute = 0
    var weekdays: Set<Int> = Set(1...7)
    /// No reminder on a day that already has a diary.
    var skipWhenWritten = true
}

enum NotificationPermission: Equatable {
    case notDetermined
    case allowed
    case denied
}

/// One scheduled reminder. The identifier carries the day so a day can be dropped once its diary is written.
struct ReminderRequest: Equatable {
    static let identifierPrefix = "diary-reminder-"

    let identifier: String
    let fireDate: DateComponents
    let title: String
    let body: String
}

/// Where the reminder settings live. Earlier versions' keys are kept, so their settings carry over.
protocol ReminderSettingsStore: AnyObject {
    var settings: ReminderSettings { get set }
    /// "yyyy-MM-dd" of today when today already has a diary, as last seen by the diary feed.
    var writtenDay: String? { get set }
    /// After a user change, until that user's first diaries arrive. Kept here so every reminders instance
    /// (the app-wide one and the settings screen's) holds off rescheduling in the meantime.
    var awaitingDiaries: Bool { get set }
    /// A change made while waiting, to be scheduled once the diaries arrive.
    var rescheduleWhenDiariesArrive: Bool { get set }
}

@MainActor
protocol ReminderScheduling {
    func permission() async -> NotificationPermission
    /// Asks the user once; false when refused.
    func requestPermission() async -> Bool
    /// Replaces every reminder this app scheduled (including earlier versions' weekly ones) with `requests`.
    func replace(with requests: [ReminderRequest]) async
}

/// Local notifications cannot skip one day of a repeating trigger, so reminders are scheduled one per day for the
/// next weeks and refreshed whenever the app becomes active, the settings change, or today's diary appears.
enum ReminderPlan {
    /// iOS keeps at most 64 pending notifications; four weeks stays well below that.
    static let days = 28

    static func requests(for settings: ReminderSettings, writtenDay: String?, now: Date,
                         calendar: Calendar) -> [ReminderRequest] {
        guard settings.isOn, !settings.weekdays.isEmpty else { return [] }
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset -> ReminderRequest? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  settings.weekdays.contains(calendar.component(.weekday, from: day)),
                  let fire = calendar.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: day),
                  fire > now else { return nil }
            let key = dayKey(day, calendar: calendar)
            if settings.skipWhenWritten, key == writtenDay { return nil }
            let message = message(for: day, calendar: calendar)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            return ReminderRequest(identifier: ReminderRequest.identifierPrefix + key, fireDate: components,
                                   title: message.title, body: message.body)
        }
    }

    /// "매일", "평일", "주말", or the days in order, e.g. "월, 수, 금".
    static func summary(of weekdays: Set<Int>) -> String {
        switch weekdays {
        case Set(1...7): return "매일"
        case Set(2...6): return "평일"
        case [1, 7]: return "주말"
        case []: return "요일을 선택하세요"
        default:
            // Monday first, as Korean calendars read.
            return [2, 3, 4, 5, 6, 7, 1].filter(weekdays.contains).map { weekdayNames[$0 - 1] }.joined(separator: ", ")
        }
    }

    static let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Whether `entries` include a diary for the day of `now` that is not in the trash.
    static func hasDiary(on now: Date, in entries: [DiaryEntry], calendar: Calendar) -> Bool {
        entries.contains { !$0.isDeleted && calendar.isDate($0.date, inSameDayAs: now) }
    }

    // A different gentle prompt each day, so the reminder does not read the same every evening.
    private static let messages: [(title: String, body: String)] = [
        ("오늘의 여정을 기록해보세요", "오늘 하루를 되돌아보며 얻은 경험들을 기록해보는 건 어떨까요?"),
        ("오늘 하루는 어땠나요?", "짧게라도 좋아요. 오늘의 마음을 남겨보세요."),
        ("하루일기 쓸 시간이에요", "오늘 가장 기억에 남는 순간은 무엇이었나요?"),
        ("오늘의 한 줄", "한 줄만 적어도 오늘이 조금 더 오래 남아요."),
        ("잠들기 전 잠깐", "오늘 고마웠던 일 하나를 적어볼까요?"),
        ("오늘의 날씨와 기분", "오늘의 날씨와 기분을 골라 가볍게 시작해보세요."),
        ("여정의 불을 밝혀요", "일기를 쓰면 이번 달 여정 그림이 한 칸 더 채워져요.")
    ]

    static func message(for day: Date, calendar: Calendar) -> (title: String, body: String) {
        let index = (calendar.ordinality(of: .day, in: .era, for: day) ?? 0) % messages.count
        return messages[index]
    }
}
