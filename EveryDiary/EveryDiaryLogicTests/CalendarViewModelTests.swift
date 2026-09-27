import Foundation
import XCTest
import UIKit

@MainActor
final class CalendarViewModelTests: XCTestCase {
    func testAppCompositionUsesInjectedCalendarClockAndImageLoader() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: -8 * 3600))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-01T02:00:00Z"))
        let imageLoader = FakeCalendarImageLoader()
        let repository = FakeDiaryRepository()
        let session = FakeDiarySession(userID: nil)
        let dependencies = AppDependencies(
            diaryRepository: repository, userSession: session,
            calendarImageLoader: imageLoader, calendar: calendar, now: { now }
        )
        let module = dependencies.makeCalendarModule()
        let anotherModule = dependencies.makeCalendarModule()
        XCTAssertFalse(module.viewModel === anotherModule.viewModel)
        XCTAssertTrue(repository.observations.isEmpty)
        XCTAssertEqual(session.observationCount, 0)
        XCTAssertEqual(module.viewModel.calendar.timeZone, calendar.timeZone)
        XCTAssertEqual(calendar.component(.year, from: module.viewModel.selectedDate), 2025)
        XCTAssertEqual(calendar.component(.month, from: module.viewModel.selectedDate), 12)
        XCTAssertEqual(calendar.component(.day, from: module.viewModel.selectedDate), 31)
        let url = try XCTUnwrap(URL(string: "https://example.invalid/image"))
        let image = await module.imageLoader.image(for: url)
        XCTAssertTrue(image === imageLoader.result)
        XCTAssertEqual(imageLoader.requestedURL, url)
        let anotherImage = await anotherModule.imageLoader.image(for: url)
        XCTAssertTrue(anotherImage === imageLoader.result)
    }

    func testAppCompositionLoadsInjectedRepositoryAndClearsOnInjectedSessionLogout() async throws {
        let repository = FakeDiaryRepository()
        let session = FakeDiarySession(userID: "injected-user")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))
        let module = AppDependencies(
            diaryRepository: repository, userSession: session,
            calendarImageLoader: FakeCalendarImageLoader(), calendar: calendar, now: { today }
        ).makeCalendarModule()
        let model = module.viewModel
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        XCTAssertEqual(repository.observations.first?.userID, "injected-user")
        repository.send([entry("injected-diary")])
        try await waitUntil { model.selectedEntries.first?.id == "injected-diary" }
        session.send(nil)
        try await waitUntil { model.selectedEntries.isEmpty && model.state == .loaded }
        try await waitUntil { repository.terminated.contains(0) }
    }

    func testAppCompositionReadsClockAgainWhenUserChanges() async throws {
        let repository = FakeDiaryRepository()
        let session = FakeDiarySession(userID: "first")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        var today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 31)))
        let model = AppDependencies(
            diaryRepository: repository, userSession: session,
            calendarImageLoader: FakeCalendarImageLoader(), calendar: calendar, now: { today }
        ).makeCalendarModule().viewModel
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
        session.send("second")
        try await waitUntil { repository.observations.count == 2 }
        XCTAssertEqual(calendar.component(.year, from: model.selectedDate), 2027)
        XCTAssertEqual(calendar.component(.month, from: model.selectedDate), 1)
        XCTAssertEqual(calendar.component(.day, from: model.selectedDate), 1)
    }


    private func makeModel(userID: String? = "user-a") throws -> (CalendarViewModel, FakeDiaryRepository, FakeDiarySession) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        let today = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-15T00:00:00Z"))
        let repository = FakeDiaryRepository()
        let session = FakeDiarySession(userID: userID)
        let model = CalendarViewModel(repository: repository, session: session, calendar: calendar, now: { today })
        return (model, repository, session)
    }

    private func entry(_ id: String, day: Int = 15, isDeleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: id, content: "테스트 본문", date: Date(timeIntervalSince1970: 0), emotion: "Grinning face", weather: "u_sun")
        entry.id = id
        entry.dateString = "2026-09-\(day) 09:00:00 +0900"
        entry.isDeleted = isDeleted
        return entry
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for observable state", file: file, line: line)
    }

    func testLoadingContentAndSuccessfulEmptySnapshotAreDistinct() async throws {
        let (model, repository, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { model.state == .loading }
        repository.send([entry("first")])
        try await waitUntil { model.selectedEntries.first?.id == "first" }
        XCTAssertEqual(model.state, .loaded)
        repository.send([])
        try await waitUntil { model.selectedEntries.isEmpty && model.state == .loaded }
        XCTAssertTrue(model.index.decoratedDays.isEmpty)
    }

    func testFailureIsNotReportedAsAnEmptySuccessfulResultAndRetryRecovers() async throws {
        let (model, repository, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.fail()
        try await waitUntil { model.state == .failed }
        model.retry()
        XCTAssertEqual(model.state, .loading)
        repository.send([entry("recovered")])
        try await waitUntil { model.selectedEntries.first?.id == "recovered" }
        XCTAssertEqual(model.state, .loaded)
    }

    func testFailedRefreshKeepsPreviouslyLoadedEntries() async throws {
        let (model, repository, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("cached")])
        try await waitUntil { model.selectedEntries.count == 1 }
        repository.fail()
        try await waitUntil { model.state == .failed }
        XCTAssertEqual(model.selectedEntries.first?.id, "cached")
    }

    func testSelectionReadsFromSameSnapshotWithoutStartingAnotherSubscription() async throws {
        let (model, repository, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("today"), entry("yesterday", day: 14)])
        try await waitUntil { model.state == .loaded }
        let yesterday = try XCTUnwrap(model.calendar.date(byAdding: .day, value: -1, to: model.selectedDate))
        model.select(yesterday)
        XCTAssertEqual(model.selectedEntries.first?.id, "yesterday")
        XCTAssertTrue(model.index.decoratedDays.contains(model.selectedDay))
        XCTAssertEqual(repository.observations.count, 1)
    }

    func testDeletionAndDateMoveUpdateSelectedListAndDecorationTogether() async throws {
        let (model, repository, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("moved"), entry("deleted")])
        try await waitUntil { model.selectedEntries.count == 2 }
        let originalDay = model.selectedDay
        repository.send([entry("moved", day: 16), entry("deleted", isDeleted: true)])
        try await waitUntil { model.selectedEntries.isEmpty }
        XCTAssertFalse(model.index.decoratedDays.contains(originalDay))
        XCTAssertEqual(model.index.decoratedDays.count, 1)
    }

    func testUserSwitchClearsPreviousEntriesAndReleasesOldSubscription() async throws {
        let (model, repository, session) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("private-a")])
        try await waitUntil { model.selectedEntries.count == 1 }
        session.send("user-b")
        try await waitUntil { repository.observations.count == 2 }
        XCTAssertTrue(model.selectedEntries.isEmpty)
        XCTAssertTrue(model.index.decoratedDays.isEmpty)
        repository.send([entry("late-a")], observation: 0)
        repository.send([entry("private-b")])
        try await waitUntil { model.selectedEntries.first?.id == "private-b" }
        try await waitUntil { repository.terminated.contains(0) }
        XCTAssertEqual(repository.observations.last?.userID, "user-b")
    }

    func testLogoutClearsEntriesWithoutReadingAnonymousOrPreviousUserData() async throws {
        let (model, repository, session) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("private")])
        try await waitUntil { model.selectedEntries.count == 1 }
        session.send(nil)
        try await waitUntil { model.selectedEntries.isEmpty && model.state == .loaded }
        repository.send([entry("late")], observation: 0)
        try await waitUntil { repository.terminated.contains(0) }
        XCTAssertTrue(model.index.decoratedDays.isEmpty)
        XCTAssertEqual(repository.observations.count, 1)
    }

    func testRepeatedStartAndSameUserEventDoNotDuplicateObservation() async throws {
        let (model, repository, session) = try makeModel()
        model.start()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        session.send("user-a")
        repository.send([entry("same-user")])
        try await waitUntil { model.selectedEntries.count == 1 }
        XCTAssertEqual(repository.observations.count, 1)
        XCTAssertEqual(session.observationCount, 1)
    }

    func testStopReleasesSubscriptionsAndReentryPreservesSelectedDate() async throws {
        let (model, repository, _) = try makeModel()
        model.start()
        try await waitUntil { repository.observations.count == 1 }
        model.moveMonth(by: -1)
        let selectedDate = model.selectedDate
        model.stop()
        try await waitUntil { repository.terminated.contains(0) }
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 2 }
        XCTAssertEqual(model.selectedDate, selectedDate)
    }

    func testViewModelDeallocationReleasesObservationTasks() async throws {
        let repository = FakeDiaryRepository()
        let session = FakeDiarySession(userID: "user-a")
        let holder = ModelHolder()
        holder.model = CalendarViewModel(repository: repository, session: session, calendar: .current)
        weak var weakModel = holder.model
        holder.model?.start()
        try await waitUntil { repository.observations.count == 1 }
        holder.model = nil
        try await waitUntil { weakModel == nil && repository.terminated.contains(0) }
    }

    func testMonthMovementCrossesYearAndStopsBeforeLegacyMinimumYear() throws {
        let (model, _, _) = try makeModel()
        let january = try XCTUnwrap(model.calendar.date(from: DateComponents(year: 2011, month: 1, day: 15)))
        model.select(january)
        XCTAssertFalse(model.canMoveToPreviousMonth)
        model.moveMonth(by: -1)
        XCTAssertEqual(model.calendar.component(.year, from: model.displayedMonth), 2011)
        XCTAssertEqual(model.calendar.component(.month, from: model.displayedMonth), 1)
        let december = try XCTUnwrap(model.calendar.date(from: DateComponents(year: 2025, month: 12, day: 15)))
        model.select(december)
        model.moveMonth(by: 1)
        XCTAssertEqual(model.calendar.component(.year, from: model.displayedMonth), 2026)
        XCTAssertEqual(model.calendar.component(.month, from: model.displayedMonth), 1)
        XCTAssertEqual(model.calendar.component(.day, from: model.selectedDate), 1)
    }
}

@MainActor
private final class ModelHolder {
    var model: CalendarViewModel?
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
        observations.last?.continuation.finish(throwing: NSError(domain: "CalendarTests", code: 1))
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

@MainActor
private final class FakeCalendarImageLoader: CalendarImageLoading {
    let result = UIImage()
    private(set) var requestedURL: URL?

    func image(for url: URL) async -> UIImage? {
        requestedURL = url
        return result
    }
}
