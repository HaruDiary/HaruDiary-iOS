import Foundation
import Observation

/// Settings › 알림: the daily writing reminder, its time, weekdays and whether a written day is skipped.
/// Every change is saved and rescheduled at once, so leaving the screen never loses a change.
@MainActor
@Observable
final class ReminderSettingsViewModel {
    enum Preset: CaseIterable {
        case everyday
        case weekdays
        case weekend

        var title: String {
            switch self {
            case .everyday: return "매일"
            case .weekdays: return "평일"
            case .weekend: return "주말"
            }
        }

        var weekdays: Set<Int> {
            switch self {
            case .everyday: return Set(1...7)
            case .weekdays: return Set(2...6)
            case .weekend: return [1, 7]
            }
        }
    }

    private(set) var settings: ReminderSettings
    private(set) var permission: NotificationPermission = .notDetermined
    private(set) var nextReminder: Date?

    private let reminders: DiaryReminders
    private let calendar: Calendar
    private let now: () -> Date

    init(reminders: DiaryReminders, calendar: Calendar, now: @escaping () -> Date) {
        self.reminders = reminders
        self.calendar = calendar
        self.now = now
        settings = reminders.settings
    }

    /// On appear and when returning from the iPhone Settings app.
    func load() async {
        permission = await reminders.permission()
        settings = reminders.settings
        nextReminder = reminders.nextReminder()
    }

    /// Reminders were turned on here but iPhone settings do not allow them.
    var isBlocked: Bool { settings.isOn && permission == .denied }

    func setOn(_ on: Bool) async {
        guard on != settings.isOn else { return }
        if on {
            if permission == .notDetermined {
                _ = await reminders.requestPermission()
                permission = await reminders.permission()
            }
            guard permission == .allowed else { return }
        }
        var changed = settings
        changed.isOn = on
        if on && changed.weekdays.isEmpty { changed.weekdays = Set(1...7) }
        await apply(changed)
    }

    var time: Date {
        calendar.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: now()) ?? now()
    }

    func setTime(_ date: Date) async {
        var changed = settings
        changed.hour = calendar.component(.hour, from: date)
        changed.minute = calendar.component(.minute, from: date)
        guard changed != settings else { return }
        await apply(changed)
    }

    func toggle(weekday: Int) async {
        guard (1...7).contains(weekday) else { return }
        var changed = settings
        if changed.weekdays.contains(weekday) {
            changed.weekdays.remove(weekday)
        } else {
            changed.weekdays.insert(weekday)
        }
        await apply(changed)
    }

    func apply(_ preset: Preset) async {
        var changed = settings
        changed.weekdays = preset.weekdays
        await apply(changed)
    }

    func setSkipWhenWritten(_ skip: Bool) async {
        var changed = settings
        changed.skipWhenWritten = skip
        await apply(changed)
    }

    var summary: String { ReminderPlan.summary(of: settings.weekdays) }

    /// "다음 알림: 오늘 오후 9:00", "내일 …", or the date for later days.
    var nextReminderText: String? {
        guard settings.isOn, let next = nextReminder else { return nil }
        let time = next.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "ko_KR")))
        let day: String
        if calendar.isDate(next, inSameDayAs: now()) {
            day = "오늘"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now()), calendar.isDate(next, inSameDayAs: tomorrow) {
            day = "내일"
        } else {
            let parts = calendar.dateComponents([.month, .day, .weekday], from: next)
            day = "\(parts.month ?? 0)월 \(parts.day ?? 0)일 (\(ReminderPlan.weekdayNames[(parts.weekday ?? 1) - 1]))"
        }
        return "다음 알림: \(day) \(time)"
    }

    private func apply(_ changed: ReminderSettings) async {
        settings = changed
        await reminders.update(changed)
        nextReminder = reminders.nextReminder()
    }
}
