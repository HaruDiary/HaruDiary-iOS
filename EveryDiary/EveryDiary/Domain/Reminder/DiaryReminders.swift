import Foundation

/// Keeps the scheduled writing reminders in step with the settings, the date, and whether today's diary exists.
@MainActor
final class DiaryReminders {
    private let store: any ReminderSettingsStore
    private let scheduler: any ReminderScheduling
    private let calendar: Calendar
    private let now: () -> Date
    private var feed: UserDiaryFeed?
    /// The last reschedule; each one waits for the previous so an older one never finishes last.
    private var lastReschedule: Task<Void, Never>?

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
        // Turning reminders off only removes them, which is safe at any time; adding waits for the diaries.
        if settings.isOn {
            await rescheduleUnlessWaiting()
        } else {
            await reschedule()
        }
    }

    /// The next reminder that will actually be delivered, for showing in settings.
    func nextReminder() -> Date? {
        ReminderPlan.requests(for: store.settings, writtenDay: currentWrittenDay, now: now(), calendar: calendar)
            .first.flatMap { calendar.date(from: $0.fireDate) }
    }

    /// When the app becomes active: moves the four-week window forward and forgets yesterday's diary.
    func refresh() async {
        await rescheduleUnlessWaiting()
    }

    /// Follows the signed-in user's diaries so a reminder is dropped as soon as today's diary is written.
    func watch(_ feed: UserDiaryFeed) {
        self.feed = feed
        store.awaitingDiaries = true
        feed.onEvent = { [weak self] event in
            Task { await self?.handle(event) }
        }
        feed.start()
    }

    /// Only a received list changes the schedule. Until a new user's diaries arrive (or when loading fails),
    /// the current schedule stays, so a day that already has a diary is not reminded of in the meantime.
    func handle(_ event: UserDiaryFeed.Event) async {
        switch event {
        case .userChanged:
            store.awaitingDiaries = true
        case .received(let entries):
            store.awaitingDiaries = false
            let pendingRefresh = store.rescheduleWhenDiariesArrive
            store.rescheduleWhenDiariesArrive = false
            if await !diariesChanged(entries), pendingRefresh {
                await reschedule()
            }
        case .loading, .failed:
            break
        }
    }

    /// Returns whether it rescheduled.
    @discardableResult
    func diariesChanged(_ entries: [DiaryEntry]) async -> Bool {
        let today = now()
        let written = ReminderPlan.hasDiary(on: today, in: entries, calendar: calendar)
            ? ReminderPlan.dayKey(today, calendar: calendar) : nil
        guard written != currentWrittenDay else { return false }
        store.writtenDay = written
        await reschedule()
        return true
    }

    /// The stored day only counts while it is still today.
    private var currentWrittenDay: String? {
        let today = ReminderPlan.dayKey(now(), calendar: calendar)
        return store.writtenDay == today ? today : nil
    }

    /// Between a user change and that user's first diaries the schedule stays; the change is applied on arrival.
    private func rescheduleUnlessWaiting() async {
        guard !store.awaitingDiaries else {
            store.rescheduleWhenDiariesArrive = true
            return
        }
        await reschedule()
    }

    /// Runs one at a time, each reading the settings when it starts, so the latest change is what stays scheduled
    /// even when quick changes (the time wheel, several weekdays) overlap.
    private func reschedule() async {
        let previous = lastReschedule
        let task = Task { [weak self] in
            await previous?.value
            await self?.applySchedule()
        }
        lastReschedule = task
        await task.value
    }

    private func applySchedule() async {
        let requests = ReminderPlan.requests(for: store.settings, writtenDay: currentWrittenDay, now: now(),
                                             calendar: calendar)
        // Without permission nothing can be delivered; earlier reminders are still cleared when turned off.
        if !requests.isEmpty, await scheduler.permission() != .allowed { return }
        await scheduler.replace(with: requests)
    }
}
