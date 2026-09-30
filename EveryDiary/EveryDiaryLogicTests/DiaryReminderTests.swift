import XCTest

final class InMemoryReminderStore: ReminderSettingsStore {
    var settings = ReminderSettings()
    var writtenDay: String?
    var awaitingDiaries = false
    var rescheduleWhenDiariesArrive = false
}

@MainActor
final class FakeReminderScheduler: ReminderScheduling {
    var current: NotificationPermission = .allowed
    var grants = true
    /// Makes the first replace finish late, like a slow notification center.
    var delaysFirstReplace = false
    private(set) var permissionRequests = 0
    private(set) var scheduled: [ReminderRequest] = []
    private(set) var replaceCount = 0

    func permission() async -> NotificationPermission { current }

    func requestPermission() async -> Bool {
        permissionRequests += 1
        current = grants ? .allowed : .denied
        return grants
    }

    func replace(with requests: [ReminderRequest]) async {
        replaceCount += 1
        if delaysFirstReplace, replaceCount == 1 {
            try? await Task.sleep(for: .milliseconds(100))
        }
        scheduled = requests
    }
}

@MainActor
final class DiaryReminderTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()
    /// Wednesday 30 September 2026, 20:00 in Seoul.
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 20))!

    private func settings(_ weekdays: Set<Int> = Set(1...7), hour: Int = 21, skip: Bool = true) -> ReminderSettings {
        ReminderSettings(isOn: true, hour: hour, minute: 0, weekdays: weekdays, skipWhenWritten: skip)
    }

    private func entry(on date: Date, deleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: "t", content: "c", date: date, emotion: "", weather: "")
        entry.isDeleted = deleted
        return entry
    }

    // MARK: - Plan

    func testEveryDayForFourWeeksStartingTonight() {
        let requests = ReminderPlan.requests(for: settings(), writtenDay: nil, now: now, calendar: calendar)
        XCTAssertEqual(requests.count, 28)
        XCTAssertEqual(requests.first?.identifier, "diary-reminder-2026-09-30")
        XCTAssertEqual(requests.first?.fireDate, DateComponents(year: 2026, month: 9, day: 30, hour: 21, minute: 0))
        XCTAssertEqual(Set(requests.map(\.identifier)).count, 28)
    }

    func testTimeAlreadyPassedTodayStartsTomorrow() {
        let requests = ReminderPlan.requests(for: settings(hour: 19), writtenDay: nil, now: now, calendar: calendar)
        XCTAssertEqual(requests.first?.identifier, "diary-reminder-2026-10-01")
    }

    func testOnlySelectedWeekdays() {
        // Monday and Friday.
        let requests = ReminderPlan.requests(for: settings([2, 6]), writtenDay: nil, now: now, calendar: calendar)
        XCTAssertEqual(requests.count, 8)
        XCTAssertEqual(requests.prefix(2).map(\.identifier), ["diary-reminder-2026-10-02", "diary-reminder-2026-10-05"])
    }

    func testWrittenTodayIsSkippedOnlyWhenAsked() {
        let skipping = ReminderPlan.requests(for: settings(), writtenDay: "2026-09-30", now: now, calendar: calendar)
        XCTAssertEqual(skipping.first?.identifier, "diary-reminder-2026-10-01")
        let keeping = ReminderPlan.requests(for: settings(skip: false), writtenDay: "2026-09-30", now: now, calendar: calendar)
        XCTAssertEqual(keeping.first?.identifier, "diary-reminder-2026-09-30")
    }

    func testOffOrNoWeekdaysSchedulesNothing() {
        var off = settings()
        off.isOn = false
        XCTAssertTrue(ReminderPlan.requests(for: off, writtenDay: nil, now: now, calendar: calendar).isEmpty)
        XCTAssertTrue(ReminderPlan.requests(for: settings([]), writtenDay: nil, now: now, calendar: calendar).isEmpty)
    }

    func testWeekdaySummary() {
        XCTAssertEqual(ReminderPlan.summary(of: Set(1...7)), "매일")
        XCTAssertEqual(ReminderPlan.summary(of: Set(2...6)), "평일")
        XCTAssertEqual(ReminderPlan.summary(of: [1, 7]), "주말")
        XCTAssertEqual(ReminderPlan.summary(of: [1, 2, 4]), "월, 수, 일")
        XCTAssertEqual(ReminderPlan.summary(of: []), "요일을 선택하세요")
    }

    func testOnlyTodaysDiaryOutsideTheTrashCounts() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertFalse(ReminderPlan.hasDiary(on: now, in: [entry(on: yesterday)], calendar: calendar))
        XCTAssertFalse(ReminderPlan.hasDiary(on: now, in: [entry(on: now, deleted: true)], calendar: calendar))
        XCTAssertTrue(ReminderPlan.hasDiary(on: now, in: [entry(on: yesterday), entry(on: now)], calendar: calendar))
    }

    // MARK: - Keeping reminders in step

    func testWritingTodaysDiaryDropsTonightsReminder() async {
        let store = InMemoryReminderStore()
        let scheduler = FakeReminderScheduler()
        let reminders = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        await reminders.update(settings())
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-09-30")

        await reminders.diariesChanged([entry(on: now)])
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-10-01")
        let count = scheduler.replaceCount
        // The same diaries again change nothing.
        await reminders.diariesChanged([entry(on: now)])
        XCTAssertEqual(scheduler.replaceCount, count)

        // Moved to the trash: tonight's reminder comes back.
        await reminders.diariesChanged([entry(on: now, deleted: true)])
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-09-30")
    }

    // Quick changes overlap; the slower earlier one must not leave the older schedule behind.
    func testTheLatestChangeStaysScheduledWhenChangesOverlap() async {
        let scheduler = FakeReminderScheduler()
        scheduler.delaysFirstReplace = true
        let store = InMemoryReminderStore()
        let reminders = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        let first = Task { await reminders.update(settings(hour: 22)) }
        // The first change is now inside its slow replace; the second one arrives meanwhile.
        while scheduler.replaceCount == 0 { await Task.yield() }
        await reminders.update(settings(hour: 23))
        await first.value
        XCTAssertEqual(store.settings.hour, 23)
        XCTAssertEqual(scheduler.scheduled.first?.fireDate.hour, 23)
    }

    // A new user's first diaries have not arrived yet: tonight's skip must stay until they do.
    func testSwitchingUsersWaitsForTheirDiariesBeforeRescheduling() async {
        let store = InMemoryReminderStore()
        let scheduler = FakeReminderScheduler()
        let reminders = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        await reminders.update(settings())
        await reminders.handle(.received([entry(on: now)]))
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-10-01")
        let count = scheduler.replaceCount

        await reminders.handle(.userChanged(isDifferentUser: true))
        await reminders.handle(.loading)
        await reminders.handle(.failed)
        XCTAssertEqual(scheduler.replaceCount, count)
        XCTAssertEqual(store.writtenDay, "2026-09-30")

        await reminders.handle(.received([]))
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-09-30")
    }

    // Becoming active right after launch or a user switch: the new user's diaries decide tonight, not the old day.
    func testBecomingActiveWaitsForTheUsersDiaries() async {
        let store = InMemoryReminderStore()
        store.settings = settings()
        let scheduler = FakeReminderScheduler()
        let reminders = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        await reminders.handle(.userChanged(isDifferentUser: true))
        await reminders.refresh()
        XCTAssertEqual(scheduler.replaceCount, 0)

        // The new user already wrote today on another device.
        await reminders.handle(.received([entry(on: now)]))
        XCTAssertEqual(scheduler.replaceCount, 1)
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-10-01")

        await reminders.refresh()
        XCTAssertEqual(scheduler.replaceCount, 2)
    }

    // The settings screen has its own instance; it must also wait for the new user's diaries.
    func testSettingsScreenChangesWaitForTheNewUsersDiaries() async {
        let store = InMemoryReminderStore()
        store.settings = settings()
        store.writtenDay = "2026-09-29"
        let scheduler = FakeReminderScheduler()
        let appWide = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        let screen = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        await appWide.handle(.userChanged(isDifferentUser: true))

        await screen.update(settings(hour: 22))
        XCTAssertEqual(store.settings.hour, 22)
        XCTAssertEqual(scheduler.replaceCount, 0)

        await appWide.handle(.received([entry(on: now)]))
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-10-01")
        XCTAssertEqual(scheduler.scheduled.first?.fireDate.hour, 22)
    }

    func testTurningOffClearsAtOnceEvenWhileWaiting() async {
        let store = InMemoryReminderStore()
        let scheduler = FakeReminderScheduler()
        let reminders = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        await reminders.update(settings())
        XCTAssertFalse(scheduler.scheduled.isEmpty)
        await reminders.handle(.userChanged(isDifferentUser: true))
        var off = settings()
        off.isOn = false
        await reminders.update(off)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    // The previous user's last list is queued just before the switch; handled late, it must not end the wait.
    func testAListQueuedBeforeAUserSwitchIsIgnored() async {
        let store = InMemoryReminderStore()
        store.settings = settings()
        let scheduler = FakeReminderScheduler()
        let reminders = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        let late = reminders.eventArrived(.received([]))
        _ = reminders.eventArrived(.userChanged(isDifferentUser: true))
        await late?.value
        XCTAssertTrue(store.awaitingDiaries)
        XCTAssertEqual(scheduler.replaceCount, 0)

        await reminders.eventArrived(.received([entry(on: now)]))?.value
        XCTAssertFalse(store.awaitingDiaries)
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-10-01")
    }

    func testYesterdaysDiaryDoesNotSkipToday() async {
        let store = InMemoryReminderStore()
        store.settings = settings()
        store.writtenDay = "2026-09-29"
        let scheduler = FakeReminderScheduler()
        let reminders = DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now })
        await reminders.refresh()
        XCTAssertEqual(scheduler.scheduled.first?.identifier, "diary-reminder-2026-09-30")
    }

    func testNothingIsScheduledWithoutPermissionButTurningOffStillClears() async {
        let scheduler = FakeReminderScheduler()
        scheduler.current = .denied
        let reminders = DiaryReminders(store: InMemoryReminderStore(), scheduler: scheduler, calendar: calendar,
                                       now: { [unowned self] in now })
        await reminders.update(settings())
        XCTAssertEqual(scheduler.replaceCount, 0)
        var off = settings()
        off.isOn = false
        await reminders.update(off)
        XCTAssertEqual(scheduler.replaceCount, 1)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    // MARK: - Stored settings

    func testEarlierVersionsSettingsAreReadAndKeptWhenTurnedOff() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "DiaryReminderTests"))
        defaults.removePersistentDomain(forName: "DiaryReminderTests")
        defer { defaults.removePersistentDomain(forName: "DiaryReminderTests") }
        // What the earlier NotificationVC saved: on, 22:30, Monday and Wednesday (Sunday first).
        defaults.set(true, forKey: "isSwitchOn")
        defaults.set(calendar.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 22, minute: 30)), forKey: "selectedTime")
        defaults.set([false, true, false, true, false, false, false], forKey: "selectedDays")

        let store = UserDefaultsReminderStore(defaults: defaults, calendar: calendar)
        XCTAssertEqual(store.settings, ReminderSettings(isOn: true, hour: 22, minute: 30, weekdays: [2, 4], skipWhenWritten: true))

        var off = store.settings
        off.isOn = false
        store.settings = off
        XCTAssertEqual(store.settings.hour, 22)
        XCTAssertEqual(store.settings.weekdays, [2, 4])
        XCTAssertEqual(defaults.array(forKey: "selectedDays") as? [Bool], [false, true, false, true, false, false, false])
    }

    // MARK: - Settings screen

    func testTurningOnAsksForPermissionOnceAndStaysOffWhenRefused() async {
        let scheduler = FakeReminderScheduler()
        scheduler.current = .notDetermined
        scheduler.grants = false
        let store = InMemoryReminderStore()
        let model = ReminderSettingsViewModel(
            reminders: DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now }),
            calendar: calendar, now: { [unowned self] in now })
        await model.load()
        await model.setOn(true)
        XCTAssertFalse(model.settings.isOn)
        XCTAssertEqual(model.permission, .denied)
        await model.setOn(true)
        XCTAssertEqual(scheduler.permissionRequests, 1)
    }

    func testChangesAreSavedAtOnceAndShowTheNextReminder() async {
        let scheduler = FakeReminderScheduler()
        let store = InMemoryReminderStore()
        let model = ReminderSettingsViewModel(
            reminders: DiaryReminders(store: store, scheduler: scheduler, calendar: calendar, now: { [unowned self] in now }),
            calendar: calendar, now: { [unowned self] in now })
        await model.load()
        await model.setOn(true)
        XCTAssertTrue(store.settings.isOn)
        XCTAssertEqual(model.nextReminderText, "다음 알림: 오늘 오후 9:00")

        await model.setTime(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 7, minute: 30))!)
        XCTAssertEqual(store.settings.hour, 7)
        XCTAssertEqual(model.nextReminderText, "다음 알림: 내일 오전 7:30")

        await model.apply(.weekend)
        XCTAssertEqual(model.summary, "주말")
        XCTAssertEqual(model.nextReminderText, "다음 알림: 10월 3일 (토) 오전 7:30")
        await model.toggle(weekday: 7)
        await model.toggle(weekday: 1)
        XCTAssertTrue(store.settings.weekdays.isEmpty)
        XCTAssertNil(model.nextReminderText)
    }
}
