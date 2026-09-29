import Foundation
import XCTest

@MainActor
final class JourneyViewModelTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        return calendar
    }

    private func entry(_ day: Int, month: Int = 9, isDeleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: "제목", content: "테스트 본문", date: Date(timeIntervalSince1970: 0), emotion: "Grinning face", weather: "u_sun")
        entry.dateString = String(format: "2026-%02d-%02d 09:00:00 +0900", month, day)
        entry.isDeleted = isDeleted
        return entry
    }

    private func makeModel(userID: String? = "user-a", today: @escaping () -> Date) -> (JourneyViewModel, FakeDiaryRepository, FakeDiarySession) {
        let repository = FakeDiaryRepository()
        let session = FakeDiarySession(userID: userID)
        let model = JourneyModule(repository: repository, session: session, calendar: calendar, now: today).viewModel
        return (model, repository, session)
    }

    private func date(month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for observable state", file: file, line: line)
    }

    func testNothingIsObservedBeforeStart() {
        let (_, repository, session) = makeModel { self.date(month: 9, day: 20) }
        XCTAssertTrue(repository.observations.isEmpty)
        XCTAssertEqual(session.observationCount, 0)
    }

    func testCurrentMonthCountsDiaryDaysOfTodaysMonthOnly() async throws {
        let (model, repository, _) = makeModel { self.date(month: 9, day: 20) }
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry(3), entry(3), entry(10), entry(12, isDeleted: true), entry(5, month: 8)])
        try await waitUntil { model.state == .loaded }
        XCTAssertEqual(model.currentMonth.days, [3, 10])
        XCTAssertEqual(model.numberOfDaysInCurrentMonth, 30)
        XCTAssertEqual(model.record.months.map(\.title), ["2026.09", "2026.08"])
    }

    func testChangesArriveThroughTheSameSubscription() async throws {
        let (model, repository, _) = makeModel { self.date(month: 9, day: 20) }
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry(3)])
        try await waitUntil { model.currentMonth.days == [3] }
        repository.send([entry(3), entry(4)])
        try await waitUntil { model.currentMonth.days == [3, 4] }
        model.start()
        XCTAssertEqual(repository.observations.count, 1)
    }

    func testCurrentMonthFollowsTheClock() async throws {
        var today = date(month: 9, day: 30)
        let (model, repository, _) = makeModel { today }
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry(30), entry(1, month: 10)])
        try await waitUntil { model.state == .loaded }
        XCTAssertEqual(model.currentMonth.days, [30])
        today = date(month: 10, day: 1)
        XCTAssertEqual(model.currentMonth.days, [1])
        XCTAssertEqual(model.numberOfDaysInCurrentMonth, 31)
    }

    func testSwitchingUserEndsPreviousSubscriptionAndDropsItsDays() async throws {
        let (model, repository, session) = makeModel { self.date(month: 9, day: 20) }
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry(3)])
        try await waitUntil { model.currentMonth.days == [3] }
        session.send("user-b")
        try await waitUntil { repository.observations.count == 2 }
        XCTAssertEqual(repository.observations.last?.userID, "user-b")
        XCTAssertTrue(model.record.months.isEmpty)
        try await waitUntil { repository.terminated.contains(0) }
        // A late snapshot from the previous user's subscription is ignored.
        repository.send([entry(9)], observation: 0)
        repository.send([entry(7)])
        try await waitUntil { model.currentMonth.days == [7] }
    }

    func testSignOutClearsTheJourney() async throws {
        let (model, repository, session) = makeModel { self.date(month: 9, day: 20) }
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry(3)])
        try await waitUntil { model.currentMonth.days == [3] }
        session.send(nil)
        try await waitUntil { model.record.months.isEmpty && model.state == .loaded }
        try await waitUntil { repository.terminated.contains(0) }
        XCTAssertEqual(repository.observations.count, 1)
    }

    func testStopEndsTheSubscription() async throws {
        let (model, repository, _) = makeModel { self.date(month: 9, day: 20) }
        model.start()
        try await waitUntil { repository.observations.count == 1 }
        model.stop()
        try await waitUntil { repository.terminated.contains(0) }
    }

    func testCollectionShowsEveryYearWithADiaryAndTheCurrentYear() async throws {
        let (model, repository, _) = makeModel { self.date(month: 9, day: 20) }
        model.start()
        defer { model.stop() }
        XCTAssertEqual(model.years, [2026])
        try await waitUntil { repository.observations.count == 1 }
        var old = entry(3, month: 5)
        old.dateString = "2024-05-03 09:00:00 +0900"
        repository.send([entry(3), old])
        try await waitUntil { model.state == .loaded }
        XCTAssertEqual(model.years, [2026, 2024])
        XCTAssertEqual(model.month(year: 2024, month: 5).days, [3])
        XCTAssertTrue(model.month(year: 2025, month: 1).days.isEmpty)
    }

    func testMonthLengthsAndUpcomingMonths() {
        let (model, _, _) = makeModel { self.date(month: 9, day: 20) }
        XCTAssertEqual(model.numberOfDays(year: 2026, month: 2), 28)
        XCTAssertEqual(model.numberOfDays(year: 2028, month: 2), 29)
        XCTAssertEqual(model.numberOfDays(year: 2026, month: 11), 30)
        XCTAssertFalse(model.isUpcoming(year: 2026, month: 9))
        XCTAssertTrue(model.isUpcoming(year: 2026, month: 10))
        XCTAssertFalse(model.isUpcoming(year: 2025, month: 12))
        XCTAssertTrue(model.isUpcoming(year: 2027, month: 1))
    }

    func testFailureCanBeRetried() async throws {
        let (model, repository, _) = makeModel { self.date(month: 9, day: 20) }
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.fail()
        try await waitUntil { model.state == .failed }
        model.retry()
        try await waitUntil { repository.observations.count == 2 }
        repository.send([entry(5)])
        try await waitUntil { model.state == .loaded && model.currentMonth.days == [5] }
    }
}

@MainActor
private final class FakeDiaryRepository: DiaryReadingRepository {
    struct Observation {
        let userID: String
        let continuation: AsyncThrowingStream<[DiaryEntry], Error>.Continuation
    }

    private(set) var observations: [Observation] = []
    private(set) var terminated: Set<Int> = []

    func observeDiaries(userID: String) -> AsyncThrowingStream<[DiaryEntry], Error> {
        let observationID = observations.count
        let (stream, continuation) = AsyncThrowingStream<[DiaryEntry], Error>.makeStream()
        observations.append(Observation(userID: userID, continuation: continuation))
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.terminated.insert(observationID) }
        }
        return stream
    }

    func send(_ entries: [DiaryEntry], observation: Int? = nil) {
        let index = observation ?? observations.count - 1
        guard observations.indices.contains(index) else { return }
        observations[index].continuation.yield(entries)
    }

    func fail() {
        observations.last?.continuation.finish(throwing: NSError(domain: "JourneyTests", code: 1))
    }
}

@MainActor
private final class FakeDiarySession: DiaryUserSession {
    private var userID: String?
    private var continuation: AsyncStream<String?>.Continuation?
    private(set) var observationCount = 0

    init(userID: String?) {
        self.userID = userID
    }

    func observeUserIDs() -> AsyncStream<String?> {
        observationCount += 1
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
