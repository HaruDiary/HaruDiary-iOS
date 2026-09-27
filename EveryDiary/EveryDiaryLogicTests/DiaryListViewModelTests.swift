import Foundation
import XCTest

@MainActor
final class DiaryListViewModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_789_430_400)

    private func makeModel(userID: String? = "user-a") throws -> (DiaryListViewModel, ListRepository, ListSession, ListUpdater) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        let repository = ListRepository()
        let session = ListSession(userID: userID)
        let updater = ListUpdater()
        let fixedNow = now
        let model = DiaryListViewModel(repository: repository, session: session, updater: updater,
                                       calendar: calendar, now: { fixedNow })
        return (model, repository, session, updater)
    }

    private func entry(_ id: String, day: Int = 15, month: Int = 9, title: String? = nil, isDeleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: title ?? id, content: "본문", date: Date(timeIntervalSince1970: 0), emotion: "Grinning face", weather: "u_sun")
        entry.id = id
        entry.dateString = String(format: "2026-%02d-%02d 09:00:00 +0900", month, day)
        entry.isDeleted = isDeleted
        return entry
    }

    private func ids(_ model: DiaryListViewModel) -> [String?] {
        model.sections.flatMap(\.entries).map(\.id)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for observable state", file: file, line: line)
    }

    func testSnapshotBuildsMonthSectionsAfterLoading() async throws {
        let (model, repository, _, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { model.state == .loading }
        XCTAssertTrue(model.sections.isEmpty)

        repository.send([entry("aug", day: 2, month: 8), entry("sep"), entry("trashed", isDeleted: true)])
        try await waitUntil { model.state == .loaded }

        XCTAssertEqual(model.sections.map(\.id), ["2026.09", "2026.08"])
        XCTAssertEqual(ids(model), ["sep", "aug"])
    }

    func testEmptySnapshotIsLoadedAndNotAFailure() async throws {
        let (model, repository, _, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([])
        try await waitUntil { model.state == .loaded }
        XCTAssertTrue(model.sections.isEmpty)
    }

    func testFailureKeepsShownDiariesAndRetryRecovers() async throws {
        let (model, repository, _, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("cached")])
        try await waitUntil { model.state == .loaded }

        repository.fail()
        try await waitUntil { model.state == .failed }
        XCTAssertEqual(ids(model), ["cached"])

        model.retry()
        XCTAssertEqual(model.state, .loading)
        repository.send([entry("recovered")])
        try await waitUntil { model.state == .loaded }
        XCTAssertEqual(ids(model), ["recovered"])
    }

    func testSearchFiltersLiveSnapshotWithoutAnotherSubscription() async throws {
        let (model, repository, _, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("walk", title: "산책"), entry("coffee", day: 14, title: "커피")])
        try await waitUntil { model.state == .loaded }

        model.query = " 산책 "
        XCTAssertTrue(model.isSearching)
        XCTAssertEqual(ids(model), ["walk"])

        // A later change must refresh the results of the current query, not an older one.
        repository.send([entry("walk", title: "산책"), entry("coffee", day: 14, title: "커피"), entry("night-walk", day: 16, title: "밤 산책")])
        try await waitUntil { model.visibleCount == 2 }
        XCTAssertEqual(ids(model), ["night-walk", "walk"])

        model.query = ""
        XCTAssertFalse(model.isSearching)
        XCTAssertEqual(model.visibleCount, 3)
        XCTAssertEqual(repository.observations.count, 1)
    }

    func testUserSwitchClearsDiariesAndIgnoresPreviousUserResults() async throws {
        let (model, repository, session, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("private-a")])
        try await waitUntil { model.visibleCount == 1 }

        session.send("user-b")
        try await waitUntil { repository.observations.count == 2 }
        XCTAssertTrue(model.sections.isEmpty)
        XCTAssertEqual(repository.observations.last?.userID, "user-b")

        repository.send([entry("late-a")], observation: 0)
        repository.send([entry("user-b-diary")], observation: 1)
        try await waitUntil { model.visibleCount == 1 }
        XCTAssertEqual(ids(model), ["user-b-diary"])
        try await waitUntil { repository.terminated.contains(0) }
    }

    func testLogoutShowsEmptyLoadedListWithoutSubscribing() async throws {
        let (model, repository, session, _) = try makeModel()
        model.start()
        defer { model.stop() }
        try await waitUntil { repository.observations.count == 1 }
        repository.send([entry("private")])
        try await waitUntil { model.visibleCount == 1 }

        session.send(nil)
        try await waitUntil { model.sections.isEmpty && model.state == .loaded }
        XCTAssertEqual(repository.observations.count, 1)
    }

    func testUploadIndicatorStaysUntilEveryUploadFinishes() throws {
        let (model, _, _, _) = try makeModel()
        model.uploadDidStart()
        model.uploadDidStart()
        model.uploadDidFinish()
        XCTAssertTrue(model.isUploadingDiary)
        model.uploadDidFinish()
        XCTAssertFalse(model.isUploadingDiary)
        model.uploadDidFinish()
        XCTAssertFalse(model.isUploadingDiary)
    }

    func testMoveToTrashStoresDeletedCopyWithCurrentTime() async throws {
        let (model, _, _, updater) = try makeModel()
        let original = entry("diary")

        async let move: Void = model.moveToTrash(original)
        try await waitUntil { updater.requests.count == 1 }
        updater.finish(with: nil)
        await move

        let stored = try XCTUnwrap(updater.requests.first)
        XCTAssertEqual(stored.id, "diary")
        XCTAssertTrue(stored.isDeleted)
        XCTAssertEqual(stored.deleteDate, now)
        XCTAssertEqual(stored.title, original.title)
        XCTAssertEqual(stored.dateString, original.dateString)
        XCTAssertEqual(model.notice, .movedToTrash)
    }

    func testFailedMoveToTrashIsReported() async throws {
        let (model, _, _, updater) = try makeModel()

        async let move: Void = model.moveToTrash(entry("diary"))
        try await waitUntil { updater.requests.count == 1 }
        updater.finish(with: NSError(domain: "DiaryListTests", code: 1))
        await move

        XCTAssertEqual(model.notice, .trashFailed)
    }

    func testRepeatedTrashRequestIsIgnoredWhileSaving() async throws {
        let (model, _, _, updater) = try makeModel()

        async let first: Void = model.moveToTrash(entry("diary"))
        try await waitUntil { updater.requests.count == 1 }
        await model.moveToTrash(entry("diary"))
        XCTAssertEqual(updater.requests.count, 1)

        updater.finish(with: nil)
        await first
        XCTAssertEqual(model.notice, .movedToTrash)
    }

    func testDeallocationReleasesSubscription() async throws {
        let repository = ListRepository()
        var model: DiaryListViewModel? = DiaryListViewModel(
            repository: repository, session: ListSession(userID: "user-a"), updater: ListUpdater(), calendar: .current
        )
        weak var weakModel = model
        model?.start()
        try await waitUntil { repository.observations.count == 1 }
        model = nil
        try await waitUntil { weakModel == nil && repository.terminated.contains(0) }
    }
}

@MainActor
private final class ListRepository: DiaryReadingRepository {
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
        observations.last?.continuation.finish(throwing: NSError(domain: "DiaryListTests", code: 1))
    }
}

@MainActor
private final class ListSession: DiaryUserSession {
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

@MainActor
private final class ListUpdater: DiaryUpdating {
    private(set) var requests: [DiaryEntry] = []
    private var pending: [CheckedContinuation<Void, Error>] = []

    func update(_ entry: DiaryEntry) async throws {
        requests.append(entry)
        try await withCheckedThrowingContinuation { pending.append($0) }
    }

    func finish(with error: Error?) {
        guard !pending.isEmpty else { return }
        let continuation = pending.removeFirst()
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}
