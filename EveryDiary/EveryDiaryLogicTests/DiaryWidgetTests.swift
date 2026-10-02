import XCTest

@MainActor
final class DiaryWidgetTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(_ id: String, _ year: Int, _ month: Int, _ day: Int, hour: Int = 9, isDeleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: "비밀 제목 \(id)", content: "비밀 내용", date: Date(timeIntervalSince1970: 0), emotion: "Grinning face", weather: "u_sun")
        entry.id = id
        entry.dateString = String(format: "%04d-%02d-%02d %02d:00:00 +0900", year, month, day, hour)
        entry.isDeleted = isDeleted
        return entry
    }

    // MARK: - Snapshot

    func testSnapshotKeepsOnlyTheDaysWritten() throws {
        var broken = entry("broken", 2026, 10, 1)
        broken.dateString = "어제"
        let snapshot = DiaryWidgetSnapshot(entries: [
            entry("a", 2026, 10, 2, hour: 8),
            entry("b", 2026, 10, 2, hour: 22),
            entry("c", 2026, 9, 30),
            entry("deleted", 2026, 10, 1, isDeleted: true),
            entry("old", 2026, 7, 1),
            broken,
        ], calendar: calendar, today: date(2026, 10, 2))

        XCTAssertEqual(snapshot.writtenDays, [20260930, 20261002])
        // Nothing of what was written reaches the widget.
        let stored = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        XCTAssertFalse(stored.contains("비밀"))
        XCTAssertFalse(stored.contains("Grinning"))
    }

    func testADayFollowsTheCalendarNotTheStoredOffset() {
        // 2026-10-02 00:30 in Seoul is still October 1 in UTC.
        var late = entry("seoul-midnight", 2026, 10, 2)
        late.dateString = "2026-10-01 15:30:00 +0000"
        XCTAssertEqual(DiaryWidgetSnapshot(entries: [late], calendar: calendar, today: date(2026, 10, 2)).writtenDays, [20261002])
    }

    func testStatusTellsTodayTheMonthAndTheLastWeek() {
        let snapshot = DiaryWidgetSnapshot(writtenDays: [20260928, 20260930, 20261001, 20261002])

        let status = snapshot.status(on: date(2026, 10, 2, hour: 23), calendar: calendar)

        XCTAssertTrue(status.wroteToday)
        XCTAssertEqual(status.month, 10)
        XCTAssertEqual(status.daysWrittenThisMonth, 2, "September's days do not count for October")
        XCTAssertEqual(status.daysInMonth, 31)
        XCTAssertEqual(status.week.map(\.day), [26, 27, 28, 29, 30, 1, 2])
        XCTAssertEqual(status.week.map(\.isWritten), [false, false, true, false, true, true, true])
        XCTAssertEqual(status.week.map(\.isToday), [false, false, false, false, false, false, true])
        // 2026-10-02 is a Friday (6); the week starts on the Saturday before (7).
        XCTAssertEqual(status.week.map(\.weekday), [7, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(Set(status.week.map(\.id)).count, 7)
    }

    func testStatusMovesOnAtMidnightAndIntoANewMonthWithoutTheApp() {
        let snapshot = DiaryWidgetSnapshot(writtenDays: [20261030, 20261031])

        let lastDay = snapshot.status(on: date(2026, 10, 31, hour: 23), calendar: calendar)
        XCTAssertTrue(lastDay.wroteToday)
        XCTAssertEqual(lastDay.daysWrittenThisMonth, 2)

        // The same snapshot, read after midnight.
        let nextDay = snapshot.status(on: date(2026, 11, 1, hour: 0), calendar: calendar)
        XCTAssertFalse(nextDay.wroteToday)
        XCTAssertEqual(nextDay.month, 11)
        XCTAssertEqual(nextDay.daysWrittenThisMonth, 0)
        XCTAssertEqual(nextDay.daysInMonth, 30)
        XCTAssertEqual(nextDay.week.suffix(3).map(\.isWritten), [true, true, false])
    }

    func testNothingWrittenIsAnEmptyMonth() {
        let status = DiaryWidgetSnapshot.empty.status(on: date(2028, 2, 10), calendar: calendar)
        XCTAssertFalse(status.wroteToday)
        XCTAssertEqual(status.daysWrittenThisMonth, 0)
        XCTAssertEqual(status.daysInMonth, 29)
        XCTAssertEqual(status.week.filter(\.isWritten).count, 0)
    }

    // MARK: - Store

    func testStoreKeepsTheSnapshotAndReadsNothingWhenItCannot() throws {
        let suite = "diary-widget-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsDiaryWidgetStore(defaults: defaults)
        XCTAssertEqual(store.load(), .empty)

        store.save(DiaryWidgetSnapshot(writtenDays: [20261002]))
        XCTAssertEqual(UserDefaultsDiaryWidgetStore(defaults: defaults).load(), DiaryWidgetSnapshot(writtenDays: [20261002]))

        defaults.set(Data("not a snapshot".utf8), forKey: UserDefaultsDiaryWidgetStore.key)
        XCTAssertEqual(store.load(), .empty)

        // A build without the app group has no shared defaults: nothing is kept and nothing crashes.
        let missing = UserDefaultsDiaryWidgetStore(defaults: nil)
        missing.save(DiaryWidgetSnapshot(writtenDays: [20261002]))
        XCTAssertEqual(missing.load(), .empty)
    }

    // MARK: - Updater

    func testTheWidgetIsToldOnlyWhenItsDaysChange() async throws {
        let repository = WidgetRepository()
        let session = WidgetSession(userID: "user-a")
        let store = MemoryWidgetStore()
        var reloads = 0
        let updater = DiaryWidgetUpdater(feed: UserDiaryFeed(repository: repository, session: session), store: store,
                                         calendar: calendar, now: { [self] in date(2026, 10, 2) }, reloadWidgets: { reloads += 1 })
        updater.start()
        defer { updater.stop() }
        try await waitUntil { repository.continuation != nil }

        repository.continuation?.yield([entry("a", 2026, 10, 2)])
        try await waitUntil { reloads == 1 }
        XCTAssertEqual(store.snapshot, DiaryWidgetSnapshot(writtenDays: [20261002], userID: "user-a"))

        // Another diary on the same day, or an edited one, changes nothing the widget shows.
        repository.continuation?.yield([entry("a", 2026, 10, 2), entry("b", 2026, 10, 2, hour: 20)])
        repository.continuation?.yield([entry("a", 2026, 10, 2), entry("c", 2026, 10, 1)])
        try await waitUntil { reloads == 2 }
        XCTAssertEqual(store.snapshot.writtenDays, [20261001, 20261002])
    }

    func testAnotherAccountNeverSeesThePreviousAccountsDays() async throws {
        let repository = WidgetRepository()
        let session = WidgetSession(userID: "user-a")
        let store = MemoryWidgetStore()
        var reloads = 0
        let updater = DiaryWidgetUpdater(feed: UserDiaryFeed(repository: repository, session: session), store: store,
                                         calendar: calendar, now: { [self] in date(2026, 10, 2) }, reloadWidgets: { reloads += 1 })
        updater.start()
        defer { updater.stop() }
        try await waitUntil { repository.continuation != nil }
        repository.continuation?.yield([entry("a", 2026, 10, 2)])
        try await waitUntil { reloads == 1 }

        // Signed out: the days go at once.
        session.send(nil)
        try await waitUntil { reloads == 2 }
        XCTAssertEqual(store.snapshot, .empty)

        // The next account starts empty and gets only its own days.
        session.send("user-b")
        try await waitUntil { repository.observedUsers == ["user-a", "user-b"] }
        XCTAssertEqual(store.snapshot, .empty)
        repository.continuation?.yield([entry("b", 2026, 10, 1)])
        try await waitUntil { reloads == 3 }
        XCTAssertEqual(store.snapshot, DiaryWidgetSnapshot(writtenDays: [20261001], userID: "user-b"))
    }

    func testDaysLeftByAnotherAccountAreDroppedAtLaunch() async throws {
        let repository = WidgetRepository()
        let store = MemoryWidgetStore()
        store.snapshot = DiaryWidgetSnapshot(writtenDays: [20261001], userID: "user-a")
        var reloads = 0
        let updater = DiaryWidgetUpdater(feed: UserDiaryFeed(repository: repository, session: WidgetSession(userID: "user-b")), store: store,
                                         calendar: calendar, now: { [self] in date(2026, 10, 2) }, reloadWidgets: { reloads += 1 })
        updater.start()
        defer { updater.stop() }

        try await waitUntil { reloads == 1 }
        XCTAssertEqual(store.snapshot, .empty)
    }

    func testDaysAreDroppedAtLaunchWhenNobodyIsSignedIn() async throws {
        let store = MemoryWidgetStore()
        store.snapshot = DiaryWidgetSnapshot(writtenDays: [20261001], userID: "user-a")
        var reloads = 0
        let updater = DiaryWidgetUpdater(feed: UserDiaryFeed(repository: WidgetRepository(), session: WidgetSession(userID: nil)), store: store,
                                         calendar: calendar, now: { [self] in date(2026, 10, 2) }, reloadWidgets: { reloads += 1 })
        updater.start()
        defer { updater.stop() }

        try await waitUntil { reloads == 1 }
        XCTAssertEqual(store.snapshot, .empty)
    }

    func testDaysKeptFromTheLastRunStayUntilTheDiariesAreKnown() async throws {
        // At launch the same user is observed first; clearing then would blank the widget on every launch.
        let repository = WidgetRepository()
        let store = MemoryWidgetStore()
        store.snapshot = DiaryWidgetSnapshot(writtenDays: [20261001], userID: "user-a")
        var reloads = 0
        let updater = DiaryWidgetUpdater(feed: UserDiaryFeed(repository: repository, session: WidgetSession(userID: "user-a")), store: store,
                                         calendar: calendar, now: { [self] in date(2026, 10, 2) }, reloadWidgets: { reloads += 1 })
        updater.start()
        defer { updater.stop() }
        try await waitUntil { repository.continuation != nil }
        XCTAssertEqual(store.snapshot.writtenDays, [20261001])

        repository.continuation?.yield([entry("c", 2026, 10, 1)])
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(reloads, 0, "The same days need no redraw")
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out", file: file, line: line)
    }
}

private final class MemoryWidgetStore: DiaryWidgetSnapshotStoring {
    var snapshot = DiaryWidgetSnapshot.empty
    func load() -> DiaryWidgetSnapshot { snapshot }
    func save(_ snapshot: DiaryWidgetSnapshot) { self.snapshot = snapshot }
}

@MainActor
private final class WidgetRepository: DiaryReadingRepository {
    private(set) var continuation: AsyncThrowingStream<[DiaryEntry], Error>.Continuation?
    private(set) var observedUsers: [String] = []

    func observeDiaries(userID: String) -> AsyncThrowingStream<[DiaryEntry], Error> {
        let (stream, continuation) = AsyncThrowingStream<[DiaryEntry], Error>.makeStream()
        self.continuation = continuation
        observedUsers.append(userID)
        return stream
    }
}

@MainActor
private final class WidgetSession: DiaryUserSession {
    private var userID: String?
    private var continuation: AsyncStream<String?>.Continuation?

    init(userID: String?) {
        self.userID = userID
    }

    func observeUserIDs() -> AsyncStream<String?> {
        let (stream, continuation) = AsyncStream<String?>.makeStream()
        self.continuation = continuation
        continuation.yield(userID)
        return stream
    }

    func send(_ userID: String?) {
        self.userID = userID
        continuation?.yield(userID)
    }
}
