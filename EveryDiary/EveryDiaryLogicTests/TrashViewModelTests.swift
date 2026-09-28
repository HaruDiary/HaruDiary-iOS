import Foundation
import XCTest

@MainActor
final class TrashViewModelTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private var now: Date { DiaryTrashPolicy.effectiveDate.addingTimeInterval(60 * day) }

    private func makeModel(userID: String? = "user-a") throws -> (TrashViewModel, TrashRepository, TrashSession, RecordingTrash) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        let repository = TrashRepository()
        let session = TrashSession(userID: userID)
        let trash = RecordingTrash()
        let fixedNow = now
        let model = TrashViewModel(repository: repository, session: session, trash: trash, calendar: calendar, now: { fixedNow })
        return (model, repository, session, trash)
    }

    private func entry(_ id: String, title: String? = nil, trashedDaysAgo: Double? = 1, images: [String]? = nil) -> DiaryEntry {
        var entry = DiaryEntry(title: title ?? id, content: "본문", date: Date(timeIntervalSince1970: 0), emotion: "", weather: "")
        entry.id = id
        entry.dateString = "2026-09-15 09:00:00 +0900"
        entry.isDeleted = trashedDaysAgo != nil
        entry.deleteDate = trashedDaysAgo.map { now.addingTimeInterval(-$0 * day) }
        entry.imageURL = images
        return entry
    }

    private func ids(_ model: TrashViewModel) -> [String?] {
        model.sections.flatMap(\.entries).map(\.id)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for observable state", file: file, line: line)
    }

    private func loaded(_ entries: [DiaryEntry], userID: String? = "user-a") async throws -> (TrashViewModel, TrashRepository, TrashSession, RecordingTrash) {
        let (model, repository, session, trash) = try makeModel(userID: userID)
        model.start()
        try await waitUntil { repository.observations.count == 1 }
        repository.send(entries)
        try await waitUntil { model.state == .loaded }
        return (model, repository, session, trash)
    }

    func testShowsOnlyTrashedDiariesAndHidesExpiredOnes() async throws {
        let (model, _, _, trash) = try await loaded([
            entry("active", trashedDaysAgo: nil),
            entry("recent", trashedDaysAgo: 2),
            entry("expired", trashedDaysAgo: 45, images: ["old.jpg"]),
        ])
        defer { model.stop() }

        XCTAssertEqual(ids(model), ["recent"])
        XCTAssertEqual(model.trashedCount, 1)
        try await waitUntil { trash.deletions.count == 1 }
        XCTAssertEqual(trash.deletions.first?.diaryID, "expired")
        XCTAssertEqual(trash.deletions.first?.imageURLs, ["old.jpg"])
    }

    func testDaysRemainingCountsDownFromDeleteDate() async throws {
        let recent = entry("recent", trashedDaysAgo: 2)
        let (model, _, _, _) = try await loaded([recent])
        defer { model.stop() }

        XCTAssertEqual(model.daysRemaining(for: recent), 28)
        XCTAssertNil(model.daysRemaining(for: entry("active", trashedDaysAgo: nil)))
    }

    func testRestoreTargetsObservedUserAndReportsCompletion() async throws {
        let (model, _, _, trash) = try await loaded([entry("diary")])
        defer { model.stop() }

        await model.restore(entry("diary"))

        XCTAssertEqual(trash.restores.first?.diaryID, "diary")
        XCTAssertEqual(trash.restores.first?.userID, "user-a")
        XCTAssertEqual(model.notice, .completed(.restore, count: 1))
    }

    func testFailedPermanentDeleteIsReportedAndPassesPhotos() async throws {
        let (model, _, _, trash) = try await loaded([entry("diary", images: ["a.jpg", "b.jpg"])])
        defer { model.stop() }
        trash.failingIDs = ["diary"]

        await model.deletePermanently(entry("diary", images: ["a.jpg", "b.jpg"]))

        XCTAssertEqual(trash.deletions.first?.imageURLs, ["a.jpg", "b.jpg"])
        XCTAssertEqual(model.notice, .failed(.delete, succeeded: 0, failed: 1))
    }

    func testBulkActionsCoverWholeTrashEvenWhileSearching() async throws {
        let (model, _, _, trash) = try await loaded([
            entry("walk", title: "산책"),
            entry("coffee", title: "커피"),
            entry("active", trashedDaysAgo: nil),
        ])
        defer { model.stop() }
        model.query = "산책"
        XCTAssertEqual(ids(model), ["walk"])

        await model.restoreAll()

        XCTAssertEqual(Set(trash.restores.map(\.diaryID)), ["walk", "coffee"])
        XCTAssertEqual(model.notice, .completed(.restore, count: 2))
    }

    func testEmptyTrashReportsPartialFailure() async throws {
        let (model, _, _, trash) = try await loaded([entry("first"), entry("second")])
        defer { model.stop() }
        trash.failingIDs = ["second"]

        await model.emptyTrash()

        XCTAssertEqual(trash.deletions.count, 2)
        XCTAssertEqual(model.notice, .failed(.delete, succeeded: 1, failed: 1))
        XCTAssertFalse(model.isPerformingBulkAction)
    }

    func testResultArrivingAfterUserSwitchIsNotShown() async throws {
        let (model, repository, session, trash) = try await loaded([entry("diary-of-a")])
        defer { model.stop() }
        trash.suspends = true

        async let restore: Void = model.restore(entry("diary-of-a"))
        try await waitUntil { trash.restores.count == 1 }
        session.send("user-b")
        try await waitUntil { repository.observations.count == 2 }
        trash.resumeAll()
        await restore

        XCTAssertEqual(trash.restores.first?.userID, "user-a")
        XCTAssertNil(model.notice)
        XCTAssertTrue(model.sections.isEmpty)
    }

    func testActionsWithoutSignedInUserFailWithoutWriting() async throws {
        let (model, _, _, trash) = try makeModel(userID: nil)
        model.start()
        defer { model.stop() }
        try await waitUntil { model.state == .loaded }

        await model.restore(entry("orphan"))

        XCTAssertTrue(trash.restores.isEmpty)
        XCTAssertEqual(model.notice, .failed(.restore, succeeded: 0, failed: 1))
    }
}

@MainActor
private final class TrashRepository: DiaryReadingRepository {
    struct Observation {
        let userID: String
        let continuation: AsyncThrowingStream<[DiaryEntry], Error>.Continuation
    }

    private(set) var observations: [Observation] = []

    func observeDiaries(userID: String) -> AsyncThrowingStream<[DiaryEntry], Error> {
        let (stream, continuation) = AsyncThrowingStream<[DiaryEntry], Error>.makeStream()
        observations.append(Observation(userID: userID, continuation: continuation))
        return stream
    }

    func send(_ entries: [DiaryEntry]) {
        observations.last?.continuation.yield(entries)
    }
}

@MainActor
private final class TrashSession: DiaryUserSession {
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
private final class RecordingTrash: DiaryTrashing {
    struct Request {
        let diaryID: String
        let userID: String
        var imageURLs: [String] = []
    }

    var restores: [Request] = []
    var deletions: [Request] = []
    var failingIDs: Set<String> = []
    var suspends = false
    private var pending: [CheckedContinuation<Void, Never>] = []

    func moveToTrash(diaryID: String, userID: String, at date: Date) async throws {}

    func restore(diaryID: String, userID: String) async throws {
        restores.append(Request(diaryID: diaryID, userID: userID))
        try await finish(diaryID)
    }

    func deletePermanently(diaryID: String, userID: String, imageURLs: [String]) async throws -> PhotoCleanup {
        deletions.append(Request(diaryID: diaryID, userID: userID, imageURLs: imageURLs))
        try await finish(diaryID)
        return PhotoCleanup(deletedCount: imageURLs.count)
    }

    func resumeAll() {
        pending.forEach { $0.resume() }
        pending = []
    }

    private func finish(_ diaryID: String) async throws {
        if suspends {
            await withCheckedContinuation { pending.append($0) }
        }
        if failingIDs.contains(diaryID) {
            throw NSError(domain: "TrashTests", code: 1)
        }
    }
}
