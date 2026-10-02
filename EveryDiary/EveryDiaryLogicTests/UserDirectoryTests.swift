import XCTest

@MainActor
final class UserDirectoryTests: XCTestCase {
    private let uid = "a3F927kdQx81ZpLmN0vBcT5yHsW2"
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        return calendar
    }()

    private func snapshot(provider: String? = "google.com", email: String? = "a@example.com", name: String? = "하루",
                          verified: Bool = true, userID: String? = nil) -> AccountSnapshot {
        AccountSnapshot(isEmailVerified: verified, email: email, displayName: name,
                        providerIDs: provider.map { [$0] } ?? [], userID: userID ?? uid)
    }

    // MARK: - Support code

    func testSupportCodeIsTheStartOfTheAccountID() {
        XCTAssertEqual(SupportCode.make(userID: uid), "A3F9-27KD")
        // The same account gives the same code on every device and at every launch.
        XCTAssertEqual(SupportCode.make(userID: uid), SupportCode.make(userID: uid))
        XCTAssertNotEqual(SupportCode.make(userID: "b3F927kdQx81ZpLmN0vBcT5yHsW2"), "A3F9-27KD")
        XCTAssertNil(SupportCode.make(userID: "short"))
        XCTAssertNil(SupportCode.make(userID: ""))
    }

    // MARK: - Entry

    func testEntryDescribesEachKindOfAccount() {
        XCTAssertEqual(UserDirectoryEntry(snapshot()).map { [$0.supportCode, $0.provider, $0.nickname, $0.email] },
                       ["A3F9-27KD", "google", "하루", "a@example.com"])

        // Apple may give a relay address, kept as it is, or no e-mail at all: the code still tells the account apart.
        let relay = UserDirectoryEntry(snapshot(provider: "apple.com", email: "x1y2@privaterelay.appleid.com"))
        XCTAssertEqual(relay?.provider, "apple")
        XCTAssertEqual(relay?.email, "x1y2@privaterelay.appleid.com")
        let hidden = UserDirectoryEntry(snapshot(provider: "apple.com", email: nil))
        XCTAssertEqual(hidden?.supportCode, "A3F9-27KD")
        XCTAssertNil(hidden?.email)

        // The anonymous account made by saving while signed out.
        let guest = UserDirectoryEntry(snapshot(provider: nil, email: nil, name: nil, verified: false))
        XCTAssertEqual(guest?.provider, "guest")
        XCTAssertNil(guest?.nickname)

        XCTAssertEqual(UserDirectoryEntry(snapshot(provider: nil))?.provider, "other")
        XCTAssertNil(UserDirectoryEntry(AccountSnapshot(isEmailVerified: true)), "No ID, nothing to write")
    }

    // MARK: - Updater

    private func makeUpdater(session: FakeAccountSession, directory: RecordingDirectory, records: MemoryDirectoryRecords = MemoryDirectoryRecords(),
                             now: @escaping () -> Date) -> UserDirectoryUpdater {
        UserDirectoryUpdater(session: session, directory: directory, records: records, calendar: calendar, now: now)
    }

    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    func testTheAccountIsWrittenOnceADayAndAgainWhenItChanges() async throws {
        let session = FakeAccountSession()
        let directory = RecordingDirectory()
        var clock = date(2)
        let updater = makeUpdater(session: session, directory: directory, now: { clock })
        updater.start()
        updater.start()
        defer { updater.stop() }
        XCTAssertEqual(session.observationCount, 1)

        session.send(snapshot())
        try await waitUntil { directory.writes.count == 1 }
        XCTAssertEqual(directory.writes[0].userID, uid)
        XCTAssertEqual(directory.writes[0].entry.supportCode, "A3F9-27KD")
        XCTAssertEqual(directory.writes[0].seenAt, date(2))

        // The same account again on the same day (another launch, a refresh): nothing is written.
        clock = date(2, hour: 22)
        session.send(snapshot())
        // A new nickname is written at once.
        session.send(snapshot(name: "새 이름"))
        try await waitUntil { directory.writes.count == 2 }
        XCTAssertEqual(directory.writes[1].entry.nickname, "새 이름")

        // The next day it is written again, so the last visit stays current.
        clock = date(3)
        session.send(snapshot(name: "새 이름"))
        try await waitUntil { directory.writes.count == 3 }
        XCTAssertEqual(directory.writes[2].seenAt, date(3))
    }

    func testNothingIsWrittenForNobodyAndEachAccountIsWrittenUnderItsOwnID() async throws {
        let session = FakeAccountSession()
        let directory = RecordingDirectory()
        let updater = makeUpdater(session: session, directory: directory, now: { [self] in date(2) })
        updater.start()
        defer { updater.stop() }

        session.send(nil)
        session.send(snapshot())
        try await waitUntil { directory.writes.count == 1 }
        session.send(snapshot(provider: "apple.com", email: nil, name: "다른 사람", userID: "zz99XX88yy77WW66vv55UU44tt33"))
        try await waitUntil { directory.writes.count == 2 }

        XCTAssertEqual(directory.writes.map(\.userID), [uid, "zz99XX88yy77WW66vv55UU44tt33"])
        XCTAssertEqual(directory.writes[1].entry.supportCode, "ZZ99-XX88")
        XCTAssertEqual(directory.writes[1].entry.nickname, "다른 사람")
    }

    func testAFailedWriteIsTriedAgainTheNextTime() async throws {
        let session = FakeAccountSession()
        let directory = RecordingDirectory()
        directory.error = URLError(.notConnectedToInternet)
        let updater = makeUpdater(session: session, directory: directory, now: { [self] in date(2) })
        updater.start()
        defer { updater.stop() }

        session.send(snapshot())
        try await waitUntil { directory.attempts == 1 }
        XCTAssertTrue(directory.writes.isEmpty)

        directory.error = nil
        session.send(snapshot())
        try await waitUntil { directory.writes.count == 1 }
    }

    func testWhatWasWrittenIsRememberedAcrossLaunches() async throws {
        let records = MemoryDirectoryRecords()
        let directory = RecordingDirectory()
        let first = FakeAccountSession()
        let updater = makeUpdater(session: first, directory: directory, records: records, now: { [self] in date(2) })
        updater.start()
        first.send(snapshot())
        try await waitUntil { directory.writes.count == 1 }
        updater.stop()
        try await waitUntil { first.isTerminated }

        // The app is opened again the same day.
        let second = FakeAccountSession()
        let relaunched = makeUpdater(session: second, directory: directory, records: records, now: { [self] in date(2, hour: 20) })
        relaunched.start()
        defer { relaunched.stop() }
        second.send(snapshot())
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(directory.writes.count, 1)
    }

    func testWhatIsRememberedOnTheDeviceDoesNotShowTheNicknameOrEmail() async throws {
        let records = MemoryDirectoryRecords()
        let session = FakeAccountSession()
        let directory = RecordingDirectory()
        let updater = makeUpdater(session: session, directory: directory, records: records, now: { [self] in date(2) })
        updater.start()
        defer { updater.stop() }
        session.send(snapshot())
        try await waitUntil { directory.writes.count == 1 }

        let kept = try XCTUnwrap(records.lastWritten(userID: uid))
        XCTAssertFalse(kept.contains("a@example.com"))
        XCTAssertFalse(kept.contains("하루"))
        XCTAssertFalse(kept.contains("A3F9"))
        XCTAssertEqual(kept.count, 64)
    }

    // MARK: - Settings

    func testSettingsShowTheSupportCodeOfTheSignedInAccount() async throws {
        let session = FakeAccountSession()
        session.currentAccount = snapshot()
        let model = SettingsViewModel(session: session)
        XCTAssertEqual(model.supportCode, "A3F9-27KD", "Shown as soon as settings open")

        model.start()
        defer { model.stop() }
        session.send(nil)
        try await waitUntil { model.supportCode == nil }
        session.send(snapshot(provider: nil, email: nil, name: nil, verified: false))
        try await waitUntil { model.supportCode == "A3F9-27KD" }
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out", file: file, line: line)
    }
}

@MainActor
private final class RecordingDirectory: UserDirectoryWriting {
    private(set) var writes: [(entry: UserDirectoryEntry, userID: String, seenAt: Date)] = []
    private(set) var attempts = 0
    var error: Error?

    func write(_ entry: UserDirectoryEntry, userID: String, seenAt: Date) async throws {
        attempts += 1
        if let error { throw error }
        writes.append((entry, userID, seenAt))
    }
}

private final class MemoryDirectoryRecords: UserDirectoryRecordStoring {
    private var records: [String: String] = [:]
    func lastWritten(userID: String) -> String? { records[userID] }
    func setLastWritten(_ record: String, userID: String) { records[userID] = record }
}
