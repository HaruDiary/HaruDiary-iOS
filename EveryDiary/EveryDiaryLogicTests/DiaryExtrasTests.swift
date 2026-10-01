import XCTest

@MainActor
final class DiaryExtrasTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(_ id: String, _ year: Int, _ month: Int, _ day: Int, hour: Int = 9, emotion: String = "",
                       weather: String = "", content: String = "본문", photos: Int = 0, isDeleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: id, content: content, date: Date(timeIntervalSince1970: 0), emotion: emotion, weather: weather)
        entry.id = id
        entry.dateString = String(format: "%04d-%02d-%02d %02d:00:00 +0900", year, month, day, hour)
        entry.isDeleted = isDeleted
        entry.imageURL = photos > 0 ? (0..<photos).map { "https://example.com/\($0).jpg" } : nil
        return entry
    }

    // MARK: - On this day

    func testDiariesOfTheSameDateInEarlierYearsAreMemories() {
        let entries = [
            entry("last-year-evening", 2025, 10, 1, hour: 21),
            entry("last-year-morning", 2025, 10, 1, hour: 8),
            entry("three-years", 2023, 10, 1),
            entry("today", 2026, 10, 1),
            entry("yesterday-last-year", 2025, 9, 30),
            entry("deleted", 2024, 10, 1, isDeleted: true),
        ]

        let memories = DiaryMemories.onThisDay(from: entries, today: date(2026, 10, 1, hour: 23), calendar: calendar)

        XCTAssertEqual(memories.map(\.yearsAgo), [1, 3])
        XCTAssertEqual(memories[0].entries.map(\.id), ["last-year-evening", "last-year-morning"])
        XCTAssertEqual(memories[1].entries.map(\.id), ["three-years"])
    }

    func testAMemoryFollowsTheCalendarsDayNotTheStoredOffset() {
        // 2025-10-01 00:30 in Seoul is still September 30 in UTC.
        var late = entry("seoul-midnight", 2025, 10, 1, hour: 0)
        late.dateString = "2025-09-30 15:30:00 +0000"
        XCTAssertEqual(DiaryMemories.onThisDay(from: [late], today: date(2026, 10, 1), calendar: calendar).first?.entries.map(\.id),
                       ["seoul-midnight"])
    }

    func testFebruary29IsOnlyMetOnAFebruary29() {
        let leap = [entry("leap", 2024, 2, 29)]
        XCTAssertTrue(DiaryMemories.onThisDay(from: leap, today: date(2025, 2, 28), calendar: calendar).isEmpty)
        XCTAssertTrue(DiaryMemories.onThisDay(from: leap, today: date(2025, 3, 1), calendar: calendar).isEmpty)
        XCTAssertEqual(DiaryMemories.onThisDay(from: leap, today: date(2028, 2, 29), calendar: calendar).map(\.yearsAgo), [4])
    }

    func testAnUnreadableDateIsNoMemory() {
        var broken = entry("broken", 2025, 10, 1)
        broken.dateString = "어제"
        XCTAssertTrue(DiaryMemories.onThisDay(from: [broken], today: date(2026, 10, 1), calendar: calendar).isEmpty)
    }

    // MARK: - Moods

    func testMonthMoodSummaryCountsDaysDiariesAndMoods() {
        let index = CalendarDiaryIndex(entries: [
            entry("a", 2026, 9, 29, emotion: "Grinning face"),
            entry("b", 2026, 9, 29, hour: 20, emotion: "Neutral face"),
            entry("c", 2026, 9, 30, emotion: "Grinning face"),
            entry("no-mood", 2026, 9, 30, hour: 22),
            entry("october", 2026, 10, 1, emotion: "Sleeping face"),
            entry("deleted", 2026, 9, 12, emotion: "Pouting face", isDeleted: true),
        ], calendar: calendar, now: date(2026, 10, 1))

        let september = index.moodSummary(year: 2026, month: 9)

        XCTAssertEqual(september.daysWritten, 2)
        XCTAssertEqual(september.diaryCount, 4)
        XCTAssertEqual(september.moods, [.init(emotion: "Grinning face", count: 2), .init(emotion: "Neutral face", count: 1)])
        XCTAssertEqual(september.moodCount, 3)
        XCTAssertEqual(index.moodSummary(year: 2026, month: 8), MonthMoodSummary(entriesByDay: []))
    }

    func testEqualMoodCountsFollowThePickersOrder() {
        // The picker lists "좋음" (smiling eyes) before "신남" (grinning) before "졸림" (sleeping).
        let summary = MonthMoodSummary(entriesByDay: [[
            entry("1", 2026, 9, 1, emotion: "Sleeping face"),
            entry("2", 2026, 9, 1, emotion: "Smiling face with smiling eyes"),
            entry("3", 2026, 9, 1, emotion: "Grinning face"),
        ]])
        XCTAssertEqual(summary.moods.map(\.emotion), ["Smiling face with smiling eyes", "Grinning face", "Sleeping face"])
    }

    func testTheDaysMoodIsThatOfItsLatestDiaryWithOne() {
        let index = CalendarDiaryIndex(entries: [
            entry("morning", 2026, 9, 29, hour: 8, emotion: "Grinning face"),
            entry("night-no-mood", 2026, 9, 29, hour: 23),
            entry("no-mood", 2026, 9, 30),
        ], calendar: calendar, now: date(2026, 10, 1))

        XCTAssertEqual(index.emotion(on: CalendarDay(year: 2026, month: 9, day: 29)), "Grinning face")
        XCTAssertNil(index.emotion(on: CalendarDay(year: 2026, month: 9, day: 30)))
        XCTAssertNil(index.emotion(on: CalendarDay(year: 2026, month: 9, day: 1)))
    }

    // MARK: - Prompts

    func testTheSameDayGivesTheSameQuestionAndSkippingGoesThroughAll() {
        let day = date(2026, 10, 1)
        XCTAssertEqual(DiaryPrompts.prompt(on: day, calendar: calendar), DiaryPrompts.prompt(on: date(2026, 10, 1, hour: 23), calendar: calendar))
        XCTAssertNotEqual(DiaryPrompts.prompt(on: day, calendar: calendar), DiaryPrompts.prompt(on: date(2026, 10, 2), calendar: calendar))

        let seen = Set((0..<DiaryPrompts.all.count).map { DiaryPrompts.prompt(on: day, calendar: calendar, skip: $0) })
        XCTAssertEqual(seen.count, DiaryPrompts.all.count)
        XCTAssertEqual(Set(DiaryPrompts.all).count, DiaryPrompts.all.count, "No question twice")
        // After the last one it starts over.
        XCTAssertEqual(DiaryPrompts.prompt(on: day, calendar: calendar, skip: DiaryPrompts.all.count), DiaryPrompts.prompt(on: day, calendar: calendar))
    }

    // MARK: - Export

    func testExportIsOldestFirstWithNamesForMoodAndWeather() {
        let text = DiaryExport.text(from: [
            entry("둘째 날", 2026, 9, 30, hour: 21, emotion: "Persevering face", weather: "fi_wind", content: "열심히 했다", photos: 2),
            entry("첫째 날", 2026, 9, 29, content: ""),
            entry("휴지통", 2026, 9, 28, isDeleted: true),
        ], exportedAt: date(2026, 10, 1), calendar: calendar)

        XCTAssertEqual(text, """
        하루일기
        내보낸 날: 2026년 10월 1일 · 일기 2개

        ────────────────
        2026년 9월 29일 화요일 오전 9:00

        첫째 날

        ────────────────
        2026년 9월 30일 수요일 오후 9:00
        기분: 힘듦 · 날씨: 바람

        둘째 날

        열심히 했다

        (사진 2장은 이 파일에 들어 있지 않아요)

        """)
        XCTAssertFalse(text.contains("example.com"), "Photo addresses carry access tokens and are not exported")
        XCTAssertEqual(DiaryExport.fileName(exportedAt: date(2026, 10, 1), calendar: calendar), "하루일기-20261001.txt")
    }

    func testExportViewModelWritesOneFileAndRemovesItWhenLeaving() async throws {
        let repository = ExtrasRepository()
        var written: [(text: String, name: String)] = []
        var removed: [URL] = []
        let file = URL(fileURLWithPath: "/tmp/export.txt")
        let model = DiaryExportViewModel(repository: repository, session: ExtrasSession(userID: "user-a"), calendar: calendar,
                                         now: { [self] in date(2026, 10, 1) },
                                         write: { written.append(($0, $1)); return file }, remove: { removed.append($0) })
        XCTAssertEqual(model.state, .loading)

        model.start()
        try await waitUntil { repository.continuation != nil }
        repository.continuation?.yield([entry("a", 2026, 9, 29), entry("b", 2026, 9, 30), entry("gone", 2026, 9, 1, isDeleted: true)])
        try await waitUntil { model.state != .loading }

        XCTAssertEqual(model.state, .ready(file: file, diaryCount: 2))
        XCTAssertEqual(written.map(\.name), ["하루일기-20261001.txt"])
        XCTAssertTrue(written[0].text.contains("일기 2개"))

        // A later snapshot leaves the file alone: it may be in the share sheet.
        repository.continuation?.yield([entry("a", 2026, 9, 29)])
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(model.state, .ready(file: file, diaryCount: 2))
        XCTAssertEqual(written.count, 1)
        XCTAssertTrue(removed.isEmpty)

        model.stop()
        XCTAssertEqual(removed, [file])
        XCTAssertEqual(model.state, .loading)
    }

    func testExportViewModelTellsWhenThereIsNothingOrWritingFails() async throws {
        let repository = ExtrasRepository()
        var fails = false
        let model = DiaryExportViewModel(repository: repository, session: ExtrasSession(userID: "user-a"), calendar: calendar,
                                         now: { [self] in date(2026, 10, 1) },
                                         write: { _, _ in
                                             if fails { throw CocoaError(.fileWriteOutOfSpace) }
                                             return URL(fileURLWithPath: "/tmp/export.txt")
                                         }, remove: { _ in })
        model.start()
        try await waitUntil { repository.continuation != nil }

        repository.continuation?.yield([entry("gone", 2026, 9, 1, isDeleted: true)])
        try await waitUntil { model.state == .empty }

        fails = true
        repository.continuation?.yield([entry("a", 2026, 9, 29)])
        try await waitUntil { model.state == .failed }
        model.stop()
    }

    // MARK: - Draft store

    func testDraftStoreKeepsOneDraftAcrossInstances() throws {
        let suite = "diary-draft-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let draft = StoredDiaryDraft(title: "제목", content: "내용", date: date(2026, 9, 30), emotion: "Grinning face",
                                     weather: "u_sun", photoCount: 2, userID: "user-a")

        XCTAssertNil(UserDefaultsDiaryDraftStore(defaults: defaults).load(diaryID: nil))
        UserDefaultsDiaryDraftStore(defaults: defaults).save(draft)
        XCTAssertEqual(UserDefaultsDiaryDraftStore(defaults: defaults).load(diaryID: nil), draft)

        UserDefaultsDiaryDraftStore(defaults: defaults).clear(diaryID: nil)
        XCTAssertNil(UserDefaultsDiaryDraftStore(defaults: defaults).load(diaryID: nil))

        // Something this version cannot read is no draft.
        defaults.set(Data("not a draft".utf8), forKey: UserDefaultsDiaryDraftStore.key)
        XCTAssertNil(UserDefaultsDiaryDraftStore(defaults: defaults).load(diaryID: nil))
    }

    func testDraftStoreKeepsANewDiaryAndOneEditedDiaryApart() throws {
        let suite = "diary-draft-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsDiaryDraftStore(defaults: defaults)
        let new = StoredDiaryDraft(title: "새 일기", content: "", date: date(2026, 9, 30), emotion: "", weather: "", photoCount: 0, userID: "user-a")
        var edit = new
        edit.title = "고친 제목"
        edit.diaryID = "diary-1"

        store.save(new)
        store.save(edit)

        XCTAssertEqual(store.load(diaryID: nil), new)
        XCTAssertEqual(store.load(diaryID: "diary-1"), edit)
        XCTAssertNil(store.load(diaryID: "diary-2"))

        // Clearing for another diary, or the new diary's writing, leaves the kept changes.
        store.clear(diaryID: "diary-2")
        store.clear(diaryID: nil)
        XCTAssertNil(store.load(diaryID: nil))
        XCTAssertEqual(store.load(diaryID: "diary-1"), edit)

        // Editing another diary replaces them: only the latest edited diary is kept.
        var other = edit
        other.diaryID = "diary-2"
        store.save(other)
        XCTAssertNil(store.load(diaryID: "diary-1"))
        store.clear(diaryID: "diary-2")
        XCTAssertNil(store.load(diaryID: "diary-2"))
    }

    func testDraftStoreKnowsWhichDraftIsBeingSavedOnlyWhileTheAppRuns() throws {
        let suite = "diary-draft-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsDiaryDraftStore(defaults: defaults)
        let draft = StoredDiaryDraft(title: "제목", content: "", date: date(2026, 9, 30), emotion: "", weather: "", photoCount: 0, userID: "user-a")
        var other = draft
        other.title = "다른 글"
        store.save(draft)

        store.setSaving(true, draft)
        XCTAssertTrue(store.isBeingSaved(draft))
        XCTAssertFalse(store.isBeingSaved(other))
        XCTAssertEqual(store.load(diaryID: nil), draft, "It stays kept while it is saved")

        // After a restart no save is running: the kept writing comes back.
        XCTAssertFalse(UserDefaultsDiaryDraftStore(defaults: defaults).isBeingSaved(draft))

        store.setSaving(false, draft)
        XCTAssertFalse(store.isBeingSaved(draft))
    }

    func testADraftStoredBeforeEditsWereKeptIsStillRead() throws {
        // Written by the first version of the store, without `diaryID`.
        let old = #"{"title":"제목","content":"","date":0,"emotion":"","weather":"","photoCount":1}"#
        let draft = try JSONDecoder().decode(StoredDiaryDraft.self, from: Data(old.utf8))
        XCTAssertEqual(draft.title, "제목")
        XCTAssertNil(draft.diaryID)
        XCTAssertNil(draft.userID)
    }

    func testADraftBelongsToItsWriterOrToWhoeverContinuesWithoutAnAccount() {
        var draft = StoredDiaryDraft(title: "제목", content: "", date: date(2026, 9, 30), emotion: "", weather: "", photoCount: 0, userID: "user-a")
        XCTAssertTrue(draft.belongs(to: "user-a"))
        XCTAssertFalse(draft.belongs(to: "user-b"))
        XCTAssertFalse(draft.belongs(to: nil))
        draft.userID = nil
        XCTAssertTrue(draft.belongs(to: "user-b"))
        XCTAssertFalse(draft.isEmpty)
        draft.title = ""
        draft.photoCount = 3
        XCTAssertTrue(draft.isEmpty, "Photos alone cannot be brought back")
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
private final class ExtrasRepository: DiaryReadingRepository {
    private(set) var continuation: AsyncThrowingStream<[DiaryEntry], Error>.Continuation?

    func observeDiaries(userID: String) -> AsyncThrowingStream<[DiaryEntry], Error> {
        let (stream, continuation) = AsyncThrowingStream<[DiaryEntry], Error>.makeStream()
        self.continuation = continuation
        return stream
    }
}

@MainActor
private final class ExtrasSession: DiaryUserSession {
    private let userID: String?

    init(userID: String?) {
        self.userID = userID
    }

    func observeUserIDs() -> AsyncStream<String?> {
        AsyncStream { $0.yield(userID) }
    }
}
