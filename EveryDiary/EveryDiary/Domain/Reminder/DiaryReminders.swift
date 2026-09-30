import Foundation

/// Keeps the scheduled writing reminders in step with the settings, the date, and whether today's diary exists.
@MainActor
final class DiaryReminders {
    private let store: any ReminderSettingsStore
    private let scheduler: any ReminderScheduling
    private let calendar: Calendar
    private let now: () -> Date
    private var feed: UserDiaryFeed?

    init(store: any ReminderSettingsStore, scheduler: any ReminderScheduling, calendar: Calendar,
         now: @escaping () -> Date) {
        self.store = store
        self.scheduler = scheduler
        self.calendar = calendar
        self.now = now
    }

    var settings: ReminderSettings { store.settings }

    func permission() async -> NotificationPermission {
        await scheduler.permission()
    }

    func requestPermission() async -> Bool {
        await scheduler.requestPermission()
    }

    func update(_ settings: ReminderSettings) async {
        store.settings = settings
        await reschedule()
    }

    /// The next reminder that will actually be delivered, for showing in settings.
    func nextReminder() -> Date? {
        ReminderPlan.requests(for: store.settings, writtenDay: currentWrittenDay, now: now(), calendar: calendar)
            .first.flatMap { calendar.date(from: $0.fireDate) }
    }

    /// When the app becomes active: moves the four-week window forward and forgets yesterday's diary.
    func refresh() async {
        await reschedule()
    }

    /// Follows the signed-in user's diaries so a reminder is dropped as soon as today's diary is written.
    func watch(_ feed: UserDiaryFeed) {
        self.feed = feed
        feed.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .userChanged:
                Task { await self.diariesChanged([]) }
            case .received(let entries):
                Task { await self.diariesChanged(entries) }
            case .loading, .failed:
                break
            }
        }
        feed.start()
    }

    func diariesChanged(_ entries: [DiaryEntry]) async {
        let today = now()
        let written = ReminderPlan.hasDiary(on: today, in: entries, calendar: calendar)
            ? ReminderPlan.dayKey(today, calendar: calendar) : nil
        guard written != currentWrittenDay else { return }
        store.writtenDay = written
        await reschedule()
    }

    /// The stored day only counts while it is still today.
    private var currentWrittenDay: String? {
        let today = ReminderPlan.dayKey(now(), calendar: calendar)
        return store.writtenDay == today ? today : nil
    }

    private func reschedule() async {
        let requests = ReminderPlan.requests(for: store.settings, writtenDay: currentWrittenDay, now: now(),
                                             calendar: calendar)
        // Without permission nothing can be delivered; earlier reminders are still cleared when turned off.
        if !requests.isEmpty, await scheduler.permission() != .allowed { return }
        await scheduler.replace(with: requests)
    }
}
