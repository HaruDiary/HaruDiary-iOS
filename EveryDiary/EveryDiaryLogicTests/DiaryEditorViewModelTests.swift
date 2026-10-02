import UIKit
import XCTest

@MainActor
final class DiaryEditorViewModelTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()
    // 2026-09-30 21:00 in the test's time zone.
    private lazy var today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 21))!
    private lazy var lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

    private let saver = RecordingDiarySaving()
    private let downloader = FakePhotoDownloader()
    private let weather = FakeWeatherLooking()
    private let locating = FakeLocating()

    private func makeModel(drafts: (any DiaryDraftStoring)? = nil) -> DiaryEditorViewModel {
        DiaryEditorViewModel(saver: saver, downloader: downloader, weather: weather, locating: locating,
                             calendar: calendar, now: { [today] in today }, drafts: drafts)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for editor state", file: file, line: line)
    }

    private func stored(id: String = "diary-1", date: Date? = nil, photos: [String] = []) -> DiaryEntry {
        var entry = DiaryEntry(title: "산책", content: "강변", dateString: DateFormatter.yyyyMMddHHmmss.string(from: date ?? lastWeek),
                               emotion: "Grinning face", weather: "u_sun", imageURL: photos,
                               useMetadataLocation: false, currentLocationInfo: "37.5, 127.0")
        entry.id = id
        entry.userID = "user-a"
        entry.weatherDescription = "맑음"
        entry.weatherTemp = 20
        return entry
    }

    private func photo(_ id: String?, location: String? = nil, captureTime: String? = nil) -> EditorPhoto {
        EditorPhoto(image: .testPixel, assetIdentifier: id, captureTime: captureTime, location: location)
    }

    // MARK: - Writing a new diary

    func testNewDiaryStoresEditorWeatherInsteadOfLookingItUpAgain() async throws {
        weather.result = .success(WeatherResponse(description: "맑음", celsius: 23.4))
        let model = makeModel()
        model.startComposing()
        try await waitUntil { model.weather == .loaded(description: "맑음", celsius: 23.4) }
        model.draft.title = "오늘"
        model.draft.content = "좋은 하루"
        model.draft.emotion = "Grinning face"
        model.draft.weather = "u_sun"

        XCTAssertTrue(model.save())
        try await waitUntil { saver.created.count == 1 }

        let entry = try XCTUnwrap(saver.created.first)
        XCTAssertEqual(entry.title, "오늘")
        XCTAssertEqual(entry.content, "좋은 하루")
        XCTAssertEqual(entry.dateString, DateFormatter.yyyyMMddHHmmss.string(from: today))
        XCTAssertEqual(entry.emotion, "Grinning face")
        XCTAssertEqual(entry.weather, "u_sun")
        XCTAssertEqual(entry.imageURL, [])
        XCTAssertEqual(entry.weatherDescription, "맑음")
        XCTAssertEqual(entry.weatherTemp, 23.4)
        XCTAssertEqual(weather.lookups, 1)
    }

    func testNewDiaryForAnotherDayStoresUnknownWeatherWithoutLookingItUp() async throws {
        let model = makeModel()
        model.startComposing()
        model.selectDate(lastWeek)
        XCTAssertEqual(model.weather, .notToday)
        model.draft.title = "지난 일"

        XCTAssertTrue(model.save())
        try await waitUntil { saver.created.count == 1 }

        XCTAssertEqual(saver.created.first?.weatherDescription, "Unknown")
        XCTAssertEqual(saver.created.first?.weatherTemp, 0)
        XCTAssertEqual(saver.created.first?.dateString, DateFormatter.yyyyMMddHHmmss.string(from: lastWeek))
    }

    func testNewDiaryOpenedForAPickedDayIsWrittenForThatDay() async throws {
        let model = makeModel()
        // The calendar gives the start of its selected day.
        model.startComposing(on: calendar.startOfDay(for: lastWeek))

        // The day is the picked one, at the current time of day, and nothing counts as changed yet.
        XCTAssertEqual(model.draft.date, lastWeek)
        XCTAssertFalse(model.hasChanges)
        XCTAssertFalse(model.isToday)
        XCTAssertEqual(model.weather, .notToday)

        // The save tells which day it is for, so the screens can show it there.
        var started: DiarySaveStart?
        model.onSaveStarted = { started = $0 }
        model.draft.title = "지난 일"
        XCTAssertTrue(model.save())
        XCTAssertEqual(started, DiarySaveStart(day: lastWeek, isNew: true))
        try await waitUntil { saver.created.count == 1 }
        XCTAssertEqual(saver.created.first?.dateString, DateFormatter.yyyyMMddHHmmss.string(from: lastWeek))
        XCTAssertEqual(saver.created.first?.weatherDescription, "Unknown")
        XCTAssertEqual(weather.lookups, 0)
    }

    // MARK: - Kept writing

    func testWritingOfANewDiaryIsKeptAndComesBackTheNextTime() {
        let drafts = FakeDraftStore()
        let model = makeModel(drafts: drafts)
        model.startComposing()
        XCTAssertNil(drafts.stored, "Nothing written, nothing kept")

        model.draft.title = "쓰던 글"
        model.draft.content = "여기까지 썼다"
        model.draft.emotion = "Grinning face"
        model.selectDate(lastWeek)
        XCTAssertEqual(drafts.stored, StoredDiaryDraft(title: "쓰던 글", content: "여기까지 썼다", date: lastWeek, emotion: "Grinning face",
                                                       weather: "", photoCount: 0, userID: "user-a"))

        // The app is closed and opened again: another editor, the same store.
        let next = makeModel(drafts: drafts)
        next.startComposing()

        XCTAssertEqual(next.draft.title, "쓰던 글")
        XCTAssertEqual(next.draft.content, "여기까지 썼다")
        XCTAssertEqual(next.draft.emotion, "Grinning face")
        XCTAssertEqual(next.draft.date, lastWeek)
        XCTAssertEqual(next.notice, .draftRestored(photoCount: 0))
        XCTAssertTrue(next.hasChanges, "Closing asks before the writing is lost")
    }

    func testClearingTheWritingKeepsNothing() {
        let drafts = FakeDraftStore()
        let model = makeModel(drafts: drafts)
        model.startComposing()
        model.draft.title = "제목"
        XCTAssertNotNil(drafts.stored)

        model.draft.title = ""

        XCTAssertNil(drafts.stored)
    }

    func testGivingUpTheWritingForgetsIt() {
        let drafts = FakeDraftStore()
        let model = makeModel(drafts: drafts)
        model.startComposing()
        model.draft.title = "버릴 글"

        model.discardDraft()
        // A late change (the place arriving) must not bring it back.
        model.draft.currentLocationInfo = "37.5, 127.0"

        XCTAssertNil(drafts.stored)
        let next = makeModel(drafts: drafts)
        next.startComposing()
        XCTAssertEqual(next.draft.title, "")
        XCTAssertNil(next.notice)
    }

    func testASavedDiaryIsNoLongerKeptButAFailedSaveKeepsIt() async throws {
        let drafts = FakeDraftStore()
        saver.outcome = .failure(DiarySaveError.signedOut)
        let model = makeModel(drafts: drafts)
        model.startComposing()
        model.draft.title = "저장 실패할 글"
        var report: DiarySaveReport?
        model.onSaveFinished = { report = $0 }

        XCTAssertTrue(model.save())
        try await waitUntil { report != nil }
        XCTAssertEqual(report, .failed(isUpdate: false))
        XCTAssertEqual(drafts.stored?.title, "저장 실패할 글", "The writing waits for the next try")

        // The next editor brings it back, and saving it clears it.
        saver.outcome = .success(.saved)
        let next = makeModel(drafts: drafts)
        next.startComposing()
        XCTAssertEqual(next.draft.title, "저장 실패할 글")
        report = nil
        next.onSaveFinished = { report = $0 }
        XCTAssertTrue(next.save())
        try await waitUntil { report != nil }
        XCTAssertEqual(report, .saved)
        XCTAssertNil(drafts.stored)
    }

    func testASaveStillRunningNeitherComesBackNorClearsWhatTheNextEditorKeeps() async throws {
        let drafts = FakeDraftStore()
        saver.holdsCreate = true
        let first = makeModel(drafts: drafts)
        first.startComposing()
        first.draft.title = "저장 중인 글"
        var report: DiarySaveReport?
        first.onSaveFinished = { report = $0 }
        XCTAssertTrue(first.save())
        try await waitUntil { saver.heldCreate != nil }
        XCTAssertEqual(drafts.stored?.title, "저장 중인 글", "Kept until the save has succeeded")

        // The editor closed when the save started; the user writes again while it runs.
        let second = makeModel(drafts: drafts)
        second.startComposing()
        XCTAssertEqual(second.draft.title, "", "Writing that is being saved is not written again")
        XCTAssertNil(second.notice)
        XCTAssertEqual(drafts.stored?.title, "저장 중인 글", "An empty editor does not drop it either")
        second.draft.title = "다음 글"
        // A late change in the closed editor must not overwrite the next editor's writing.
        first.draft.currentLocationInfo = "37.5, 127.0"
        XCTAssertEqual(drafts.stored?.title, "다음 글")

        // The first save succeeds: the next editor's writing stays.
        saver.heldCreate?(.success(.saved))
        try await waitUntil { report != nil }
        XCTAssertEqual(report, .saved)
        XCTAssertEqual(drafts.stored?.title, "다음 글")
    }

    func testAnEditStillBeingSavedDoesNotComeBackAndItsEndClearsOnlyItsOwnChanges() async throws {
        let drafts = FakeDraftStore()
        let first = makeModel(drafts: drafts)
        first.open(stored(), editing: true)
        first.draft.title = "저장 중인 수정"
        saver.holdsKeeping = true
        XCTAssertTrue(first.save())
        XCTAssertNotNil(saver.heldKeeping)

        // Edited again while the save runs: the stored diary as it is, not the changes being saved.
        let second = makeModel(drafts: drafts)
        second.open(stored(), editing: true)
        XCTAssertEqual(second.draft.title, "산책")
        XCTAssertNil(second.notice)
        second.draft.title = "그 사이의 새 수정"

        saver.heldKeeping?(.success(.savedKeepingPhotos))
        XCTAssertEqual(drafts.storedEdit?.title, "그 사이의 새 수정")
    }

    func testWritingKeptForItsWriterIsNotRewrittenAfterASignOutOrAnAccountSwitch() {
        let drafts = FakeDraftStore()
        let model = makeModel(drafts: drafts)
        model.startComposing()
        model.draft.title = "A가 쓰던 글"
        let kept = drafts.stored
        XCTAssertEqual(kept?.userID, "user-a")

        // The app signs out by itself; a late place and more typing must not turn the draft into nobody's.
        saver.userID = nil
        model.draft.currentLocationInfo = "37.5, 127.0"
        model.draft.content = "로그아웃 뒤에 친 글"
        XCTAssertEqual(drafts.stored, kept)

        // Another account signs in while the editor is still open.
        saver.userID = "user-b"
        model.draft.content = "B로 바뀐 뒤에 친 글"
        XCTAssertEqual(drafts.stored, kept)

        // B's next new diary does not get A's writing, and opening it does not drop A's writing either.
        let next = makeModel(drafts: drafts)
        next.startComposing()
        XCTAssertEqual(next.draft.title, "")
        XCTAssertNil(next.notice)
        XCTAssertEqual(drafts.stored, kept)

        // A signs in again and continues.
        saver.userID = "user-a"
        let back = makeModel(drafts: drafts)
        back.startComposing()
        XCTAssertEqual(back.draft.title, "A가 쓰던 글")
    }

    func testChangesKeptForTheirWriterAreNotRewrittenAfterASignOut() {
        let drafts = FakeDraftStore()
        let model = makeModel(drafts: drafts)
        model.open(stored(), editing: true)
        model.draft.title = "A가 고친 제목"
        let kept = drafts.storedEdit

        saver.userID = "user-b"
        model.draft.title = "B로 바뀐 뒤 고친 제목"
        XCTAssertEqual(drafts.storedEdit, kept)

        saver.userID = "user-a"
        let next = makeModel(drafts: drafts)
        next.open(stored(), editing: true)
        XCTAssertEqual(next.draft.title, "A가 고친 제목", "The writer gets the changes back")
    }

    func testWritingStartedWithoutAnAccountBecomesTheNewAccounts() {
        let drafts = FakeDraftStore()
        saver.userID = nil
        let model = makeModel(drafts: drafts)
        model.startComposing()
        model.draft.title = "계정 없이 쓴 글"
        XCTAssertNil(drafts.stored?.userID)

        // Saving makes an account; from then on the writing is that account's.
        saver.userID = "anonymous-1"
        model.draft.content = "이어서"
        XCTAssertEqual(drafts.stored?.userID, "anonymous-1")

        // And it stays that account's when someone else signs in.
        saver.userID = "user-b"
        model.draft.content = "다른 계정"
        XCTAssertEqual(drafts.stored?.content, "이어서")
        XCTAssertEqual(drafts.stored?.userID, "anonymous-1")
    }

    func testAnotherAccountsWritingIsNotShownAndStaysUntilThisAccountWrites() {
        let drafts = FakeDraftStore()
        let others = StoredDiaryDraft(title: "남의 글", content: "", date: lastWeek, emotion: "", weather: "", photoCount: 0, userID: "user-b")
        drafts.stored = others
        let model = makeModel(drafts: drafts)

        model.startComposing()

        XCTAssertEqual(model.draft.title, "")
        XCTAssertNil(model.notice)
        XCTAssertEqual(drafts.stored, others, "Opening the editor does not drop the other account's writing")

        // One new diary's writing is kept at a time: this account's writing takes its place.
        model.draft.title = "내 글"
        XCTAssertEqual(drafts.stored?.title, "내 글")
        XCTAssertEqual(drafts.stored?.userID, "user-a")
        model.draft.title = ""
        XCTAssertNil(drafts.stored, "Its own writing is cleared as before")
    }

    func testWritingFromBeforeAnAccountExistedComesBackWithItsPhotoCount() {
        let drafts = FakeDraftStore()
        drafts.stored = StoredDiaryDraft(title: "계정 없이 쓴 글", content: "", date: lastWeek, emotion: "", weather: "u_sun", photoCount: 2, userID: nil)
        let model = makeModel(drafts: drafts)

        // Opened from the calendar for another day: the kept writing and its own day win.
        model.startComposing(on: calendar.date(byAdding: .day, value: -1, to: today))

        XCTAssertEqual(model.draft.title, "계정 없이 쓴 글")
        XCTAssertEqual(model.draft.weather, "u_sun")
        XCTAssertEqual(model.draft.date, lastWeek)
        XCTAssertEqual(model.notice, .draftRestored(photoCount: 2))
    }

    func testChangesToAStoredDiaryAreKeptApartFromANewDiarysWriting() {
        let drafts = FakeDraftStore()
        drafts.stored = StoredDiaryDraft(title: "새 일기", content: "", date: today, emotion: "", weather: "", photoCount: 0, userID: "user-a")
        let model = makeModel(drafts: drafts)
        model.open(stored(), editing: true)
        XCTAssertNil(drafts.storedEdit, "Nothing changed, nothing kept")

        model.draft.title = "고친 제목"
        model.draft.emotion = "Neutral face"

        XCTAssertEqual(drafts.storedEdit, StoredDiaryDraft(title: "고친 제목", content: "강변", date: lastWeek, emotion: "Neutral face",
                                                           weather: "u_sun", photoCount: 0, userID: "user-a", diaryID: "diary-1"))
        XCTAssertEqual(drafts.stored?.title, "새 일기", "The new diary's writing is untouched")

        // Put back as it was: nothing to keep.
        model.draft.title = "산책"
        model.draft.emotion = "Grinning face"
        XCTAssertNil(drafts.storedEdit)
    }

    func testKeptChangesComeBackWhenTheSameDiaryIsEditedAgain() {
        let drafts = FakeDraftStore()
        let model = makeModel(drafts: drafts)
        model.open(stored(), editing: true)
        model.draft.content = "강변을 오래 걸었다"

        // The app is closed and opened again, and the diary is edited again.
        let next = makeModel(drafts: drafts)
        next.open(stored(), editing: true)

        XCTAssertEqual(next.draft.content, "강변을 오래 걸었다")
        XCTAssertEqual(next.draft.title, "산책")
        XCTAssertEqual(next.notice, .editRestored(photoCount: 0))
        XCTAssertTrue(next.hasChanges, "Saving writes the change, closing asks first")

        // Another diary is not given these changes.
        let other = makeModel(drafts: drafts)
        other.open(stored(id: "diary-2"), editing: true)
        XCTAssertEqual(other.draft.content, "강변")
        XCTAssertNil(other.notice)
        XCTAssertEqual(drafts.storedEdit?.diaryID, "diary-1", "Opening another diary does not drop them")
    }

    func testKeptChangesComeBackWhenReadingTurnsIntoEditing() {
        let drafts = FakeDraftStore()
        drafts.storedEdit = StoredDiaryDraft(title: "고친 제목", content: "강변", date: lastWeek, emotion: "", weather: "",
                                             photoCount: 2, userID: "user-a", diaryID: "diary-1")
        let model = makeModel(drafts: drafts)

        model.open(stored(), editing: false)
        XCTAssertEqual(model.draft.title, "산책", "Reading shows the diary as it is stored")
        XCTAssertNil(model.notice)

        model.beginEditing()
        XCTAssertEqual(model.draft.title, "고친 제목")
        XCTAssertEqual(model.notice, .editRestored(photoCount: 2))
    }

    func testChangesKeptByAnotherAccountAreNotBroughtBack() {
        let drafts = FakeDraftStore()
        drafts.storedEdit = StoredDiaryDraft(title: "남이 고친 제목", content: "강변", date: lastWeek, emotion: "", weather: "",
                                             photoCount: 0, userID: "user-b", diaryID: "diary-1")
        let model = makeModel(drafts: drafts)

        model.open(stored(), editing: true)

        XCTAssertEqual(model.draft.title, "산책")
        XCTAssertNil(model.notice)
    }

    func testSavedChangesAreKeptNoMoreButAFailedSaveKeepsThem() async throws {
        let drafts = FakeDraftStore()
        saver.keepingOutcome = .failure(DiarySaveError.signedOut)
        let model = makeModel(drafts: drafts)
        model.open(stored(), editing: true)
        model.draft.title = "저장 실패할 수정"
        var report: DiarySaveReport?
        model.onSaveFinished = { report = $0 }

        XCTAssertTrue(model.save())
        try await waitUntil { report != nil }
        XCTAssertEqual(report, .failed(isUpdate: true))
        XCTAssertEqual(drafts.storedEdit?.title, "저장 실패할 수정")

        saver.keepingOutcome = .success(.savedKeepingPhotos)
        let next = makeModel(drafts: drafts)
        next.open(stored(), editing: true)
        XCTAssertEqual(next.draft.title, "저장 실패할 수정")
        report = nil
        next.onSaveFinished = { report = $0 }
        XCTAssertTrue(next.save())
        try await waitUntil { report != nil }
        XCTAssertEqual(report, .saved)
        XCTAssertNil(drafts.storedEdit)
    }

    func testGivingUpChangesForgetsThem() {
        let drafts = FakeDraftStore()
        let model = makeModel(drafts: drafts)
        model.open(stored(), editing: true)
        model.draft.title = "버릴 수정"
        XCTAssertNotNil(drafts.storedEdit)

        model.discardDraft()

        XCTAssertNil(drafts.storedEdit)
    }

    func testSavingAnEditedDiaryTellsItIsNotNew() {
        let model = makeModel()
        model.open(stored(), editing: true)
        var started: DiarySaveStart?
        model.onSaveStarted = { started = $0 }
        model.draft.title = "고친 제목"

        XCTAssertTrue(model.save())

        XCTAssertEqual(started, DiarySaveStart(day: lastWeek, isNew: false))
    }

    func testNewDiaryOpenedForTodayOrADayToComeIsWrittenNow() {
        let model = makeModel()
        model.startComposing(on: calendar.startOfDay(for: today))
        XCTAssertEqual(model.draft.date, today)
        XCTAssertTrue(model.isToday)

        // A day to come cannot be written for, as in the editor's own date picker.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
        model.startComposing(on: tomorrow)
        XCTAssertEqual(model.draft.date, today)

        model.startComposing()
        XCTAssertEqual(model.draft.date, today)
    }

    func testWeatherStillLoadingLeavesTheLookupToSaving() {
        weather.hangs = true
        let model = makeModel()
        model.startComposing()
        let entry = model.draft.newEntry(weather: DiaryWeatherStamp.forDiary(on: today, now: today, calendar: calendar, lookup: nil))
        XCTAssertNil(entry.weatherDescription)
        XCTAssertEqual(model.weather, .loading)
    }

    func testFailedWeatherIsShownAndStoredAsUnknown() async throws {
        weather.result = .failure(.noLocation)
        let model = makeModel()
        model.startComposing()
        try await waitUntil { model.weather == .failed(.noLocation) }
        let stamp = DiaryWeatherStamp.forDiary(on: today, now: today, calendar: calendar, lookup: .failure(.noLocation))
        XCTAssertEqual(stamp, .unavailable)
    }

    func testCurrentPlaceIsKeptWithoutMarkingTheDiaryChanged() async throws {
        locating.coordinate = DiaryCoordinate(latitude: 37.5665, longitude: 126.978)
        let model = makeModel()
        model.startComposing()
        try await waitUntil { model.draft.currentLocationInfo == "37.5665, 126.978" }
        XCTAssertFalse(model.hasChanges)
        // Stored as before, but not shown: only a photo's place is shown, when the user adds it.
        XCTAssertNil(model.placeCoordinate)
        XCTAssertNil(model.placeName)
    }

    func testEmptyTitleIsRefusedLikeBefore() {
        let model = makeModel()
        model.startComposing()
        model.draft.content = "내용만"

        XCTAssertFalse(model.save())
        XCTAssertEqual(model.notice, .titleMissing)
        XCTAssertTrue(saver.created.isEmpty)

        // Only an empty title was refused before; spaces are a title.
        model.draft.title = " "
        XCTAssertTrue(model.save())
    }

    func testSaveReportsStartAndOutcomeOnce() async throws {
        saver.outcome = .success(.savedWithMissingPhotos(1))
        let model = makeModel()
        model.startComposing()
        var events: [String] = []
        model.onSaveStarted = { _ in events.append("start") }
        model.onSaveFinished = { events.append("\($0)") }
        model.draft.title = "제목"

        XCTAssertTrue(model.save())
        XCTAssertFalse(model.save(), "A second tap while saving must not save twice")
        try await waitUntil { events.count == 2 }
        XCTAssertEqual(events, ["start", "\(DiarySaveReport.savedWithMissingPhotos(1))"])
        XCTAssertFalse(model.isSaving)
    }

    func testFailedSaveIsReported() async throws {
        saver.outcome = .failure(DiarySaveError.signedOut)
        let model = makeModel()
        model.startComposing()
        var report: DiarySaveReport?
        model.onSaveFinished = { report = $0 }
        model.draft.title = "제목"
        model.save()
        try await waitUntil { report != nil }
        XCTAssertEqual(report, .failed(isUpdate: false))
    }

    // MARK: - Photos

    func testPickedPhotosKeepSelectionOrderAndMetadata() async throws {
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("b", captureTime: "2026-09-29 10:00:00 +0000"), photo("a")], pickedIDs: ["b", "a"])
        XCTAssertEqual(model.photos.map(\.assetIdentifier), ["b", "a"])
        XCTAssertEqual(model.pickerSelection, ["b", "a"])
        XCTAssertTrue(model.hasChanges)
        XCTAssertNil(model.notice)
        XCTAssertNil(model.photoPlaceQuestion)
        model.draft.title = "사진"

        model.save()
        try await waitUntil { saver.createdUploads.count == 1 }
        let uploads = try XCTUnwrap(saver.createdUploads.first)
        XCTAssertEqual(uploads.map(\.assetIdentifier), ["b", "a"])
        XCTAssertEqual(uploads.first?.captureTime, "2026-09-29 10:00:00 +0000")
        XCTAssertFalse(uploads.first?.data.isEmpty ?? true)
    }

    func testPickingAgainKeepsPhotosAndAppendsNewOnes() {
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("a"), photo("b")], pickedIDs: ["a", "b"])
        // The picker returns every selected photo again; "a" was deselected and "c" added.
        model.finishPicking([photo("b"), photo("c")], pickedIDs: ["b", "c"])
        XCTAssertEqual(model.photos.map(\.assetIdentifier), ["b", "c"])
    }

    func testPhotoWithPlaceAsksToAddItsPlaceOnly() async throws {
        locating.names = ["37.51, 126.99": "한강공원"]
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("a"), photo("b", location: "37.51, 126.99", captureTime: "2026-09-28 18:42:00 +0900")],
                            pickedIDs: ["a", "b"])
        try await waitUntil { model.photoPlaceQuestion != nil }
        XCTAssertEqual(model.photoPlaceQuestion?.placeName, "한강공원")

        model.answerPhotoPlace(addPlace: true)
        XCTAssertNil(model.photoPlaceQuestion)
        XCTAssertTrue(model.draft.useMetadataLocation)
        XCTAssertEqual(model.draft.date, today, "Adding the place leaves the date as it is")
        XCTAssertEqual(model.placeCoordinate, DiaryCoordinate(latitude: 37.51, longitude: 126.99))
        try await waitUntil { model.placeName == "한강공원" }

        // Asked once: picking another photo with a place does not ask again.
        model.finishPicking([photo("a"), photo("b"), photo("c", location: "35.1, 129.0")], pickedIDs: ["a", "b", "c"])
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertNil(model.photoPlaceQuestion)
    }

    func testDecliningPhotoPlaceAddsNothing() async throws {
        locating.names = ["37.51, 126.99": "한강공원"]
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("b", location: "37.51, 126.99")], pickedIDs: ["b"])
        try await waitUntil { model.photoPlaceQuestion != nil }
        model.answerPhotoPlace(addPlace: false)
        XCTAssertFalse(model.draft.useMetadataLocation)
        XCTAssertNil(model.placeName)
    }

    func testPlaceCanBeRemovedAndGoesWithItsPhoto() async throws {
        locating.names = ["37.51, 126.99": "한강공원"]
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("b", location: "37.51, 126.99")], pickedIDs: ["b"])
        try await waitUntil { model.photoPlaceQuestion != nil }
        model.answerPhotoPlace(addPlace: true)
        try await waitUntil { model.placeName != nil }

        model.removePlace()
        XCTAssertFalse(model.draft.useMetadataLocation)
        XCTAssertNil(model.placeName)

        model.draft.useMetadataLocation = true
        model.removePhoto(model.photos[0].id)
        XCTAssertFalse(model.draft.useMetadataLocation, "No photo is left to take the place from")
    }

    func testLatePlaceLookupForARemovedPhotoAsksNothing() async throws {
        locating.names = ["37.51, 126.99": "한강공원"]
        locating.nameDelay = 30
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("b", location: "37.51, 126.99")], pickedIDs: ["b"])
        model.removePhoto(model.photos[0].id)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertNil(model.photoPlaceQuestion)
        XCTAssertFalse(model.draft.useMetadataLocation)
    }

    func testLatePlaceLookupAfterPickingAnotherPhotoAsksNothing() async throws {
        locating.names = ["37.51, 126.99": "한강공원"]
        locating.nameDelay = 30
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("b", location: "37.51, 126.99")], pickedIDs: ["b"])
        model.finishPicking([photo("c")], pickedIDs: ["c"])
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertNil(model.photoPlaceQuestion)
    }

    func testAddingPlaceAfterItsPhotoWasRemovedAddsNothing() async throws {
        locating.names = ["37.51, 126.99": "한강공원"]
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("b", location: "37.51, 126.99"), photo("c")], pickedIDs: ["b", "c"])
        try await waitUntil { model.photoPlaceQuestion != nil }
        model.removePhoto(model.photos[0].id)
        XCTAssertNil(model.photoPlaceQuestion, "The question for the removed photo is withdrawn")
        model.answerPhotoPlace(addPlace: true)
        XCTAssertFalse(model.draft.useMetadataLocation)
    }

    func testPickingWaitsUntilStoredPhotosArrive() async throws {
        downloader.photos = ["u1": .init(image: .testPixel, metadata: ["assetIdentifier": "a1"])]
        downloader.delays = ["u1": 30]
        let model = makeModel()
        model.open(stored(photos: ["u1"]), editing: true)
        XCTAssertFalse(model.canPickPhotos(), "Picked photos would be replaced by the arriving ones")
        XCTAssertEqual(model.notice, .photosStillLoading)

        try await waitUntil { !model.isLoadingPhotos }
        XCTAssertTrue(model.canPickPhotos())
        XCTAssertEqual(model.pickerSelection, ["a1"], "The picker now shows the stored photo as selected")
    }

    func testPickedPhotoThatCannotBeReadIsReported() {
        let model = makeModel()
        model.startComposing()
        model.pickingStarted(pickedIDs: ["a", "b", "c"])
        // "b" and "c" could not be loaded (e.g. still in iCloud).
        model.finishPicking([photo("a")], pickedIDs: ["a", "b", "c"])
        XCTAssertEqual(model.photos.map(\.assetIdentifier), ["a"])
        XCTAssertEqual(model.notice, .photosNotLoaded(2))

        model.notice = nil
        model.pickingStarted(pickedIDs: ["a", "d"])
        model.finishPicking([photo("d")], pickedIDs: ["a", "d"])
        XCTAssertNil(model.notice)
    }

    func testOnlyNewlyPickedPhotosShowPlaceholders() {
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("a")], pickedIDs: ["a"])
        model.pickingStarted(pickedIDs: ["a", "b", "c"])
        XCTAssertEqual(model.loadingPhotoCount, 2)
        model.finishPicking([photo("a"), photo("b"), photo("c")], pickedIDs: ["a", "b", "c"])
        XCTAssertEqual(model.loadingPhotoCount, 0)
    }

    func testPickerDoesNotOpenWhenPhotosItCannotShowFillTheLimit() async throws {
        downloader.photos = [
            "u1": .init(image: .testPixel, metadata: nil),
            "u2": .init(image: .testPixel, metadata: nil),
            "u3": .init(image: .testPixel, metadata: nil),
        ]
        let model = makeModel()
        model.open(stored(photos: ["u1", "u2", "u3"]), editing: true)
        try await waitUntil { !model.isLoadingPhotos }
        XCTAssertEqual(model.pickerLimit, 0)
        XCTAssertFalse(model.canPickPhotos())
        XCTAssertEqual(model.notice, .photoLimitReached)

        model.removePhoto(model.photos[0].id)
        XCTAssertTrue(model.canPickPhotos())
    }

    func testRemovingPhotoUpdatesPickerSelection() {
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("a"), photo("b")], pickedIDs: ["a", "b"])
        model.removePhoto(model.photos[0].id)
        XCTAssertEqual(model.pickerSelection, ["b"])
    }

    // MARK: - Reading and editing a stored diary

    func testReadModeShowsStoredDiaryAndCannotSave() async throws {
        downloader.photos = ["u1": .init(image: .testPixel, metadata: ["assetIdentifier": "a1", "captureTime": "t", "location": "37.1, 127.1"])]
        let model = makeModel()
        model.open(stored(photos: ["u1"]), editing: false)
        XCTAssertEqual(model.mode, .read)
        XCTAssertEqual(model.draft.title, "산책")
        XCTAssertEqual(model.draft.date, DateFormatter.yyyyMMddHHmmss.date(from: DateFormatter.yyyyMMddHHmmss.string(from: lastWeek)))
        try await waitUntil { model.photos.count == 1 }
        XCTAssertEqual(model.photos.first?.captureTime, "t")
        XCTAssertFalse(model.save())
        XCTAssertFalse(model.hasChanges)
        XCTAssertEqual(weather.lookups, 0, "A stored diary never shows today's weather")

        model.beginEditing()
        XCTAssertEqual(model.mode, .edit)
    }

    func testEditingPhotosKeepsStoredFilesInOrderAndOtherFields() async throws {
        downloader.photos = [
            "u1": .init(image: .testPixel, metadata: ["assetIdentifier": "a1", "captureTime": "t1", "location": "37.1, 127.1"]),
            "u2": .init(image: .testPixel, metadata: ["assetIdentifier": "a2"]),
        ]
        downloader.delays = ["u1": 20]
        let model = makeModel()
        model.open(stored(photos: ["u1", "u2"]), editing: true)
        try await waitUntil { !model.isLoadingPhotos }
        XCTAssertEqual(model.photos.map(\.assetIdentifier), ["a1", "a2"], "Stored order, whatever order they arrive in")
        model.draft.title = "고친 제목"
        // The picker returns the stored photos again with one more.
        model.finishPicking([photo("a1"), photo("a2"), photo("new")], pickedIDs: ["a1", "a2", "new"])
        XCTAssertTrue(model.hasChanges)

        XCTAssertTrue(model.save())
        try await waitUntil { saver.updated.count == 1 }
        let update = try XCTUnwrap(saver.updated.first)
        XCTAssertEqual(update.diaryID, "diary-1")
        XCTAssertEqual(update.expectedUserID, "user-a")
        XCTAssertEqual(update.existing, ["u1", "u2"])
        // Stored photos keep their files; only the new one is uploaded.
        XCTAssertEqual(update.slots, ["stored:u1", "stored:u2", "new:new"])
        XCTAssertEqual(update.entry.title, "고친 제목")
        XCTAssertEqual(update.entry.weatherDescription, "맑음")
        XCTAssertEqual(update.entry.currentLocationInfo, "37.5, 127.0")
        XCTAssertEqual(update.entry.userID, "user-a")
    }

    func testPhotoChangeKeepsStoredPhotoSavedWithoutIdentifier() async throws {
        downloader.photos = [
            "legacy": .init(image: .testPixel, metadata: nil),
            "u2": .init(image: .testPixel, metadata: ["assetIdentifier": "a2"]),
        ]
        let model = makeModel()
        model.open(stored(photos: ["legacy", "u2"]), editing: true)
        try await waitUntil { !model.isLoadingPhotos }
        model.removePhoto(model.photos[1].id)
        model.finishPicking([photo("n")], pickedIDs: ["n"])

        XCTAssertTrue(model.save())
        try await waitUntil { saver.updated.count == 1 }
        XCTAssertEqual(saver.updated.first?.slots, ["stored:legacy", "new:n"])
        XCTAssertEqual(saver.updated.first?.unreadable, 0, "A stored photo is never counted as unreadable")
    }

    func testSavingWaitsForPickedPhotos() {
        let model = makeModel()
        model.startComposing()
        model.draft.title = "사진과 함께"
        model.pickingStarted(pickedIDs: ["a"])

        XCTAssertFalse(model.save(), "The picked photo is not in the editor yet")
        XCTAssertEqual(model.notice, .photosStillLoading)
        XCTAssertTrue(saver.created.isEmpty)

        model.finishPicking([photo("a")], pickedIDs: ["a"])
        XCTAssertTrue(model.save())
    }

    func testEditingBeforePhotosArriveKeepsStoredPhotos() async throws {
        downloader.photos = ["u1": .init(image: .testPixel, metadata: ["assetIdentifier": "a1"])]
        downloader.hanging = ["u2"]
        let model = makeModel()
        model.open(stored(photos: ["u1", "u2"]), editing: true)
        model.draft.title = "빨리 저장"
        XCTAssertTrue(model.save())
        try await waitUntil { saver.keptPhotos.count == 1 }
        XCTAssertEqual(saver.keptPhotos.first?.existing, ["u1", "u2"])
        XCTAssertTrue(saver.updated.isEmpty)
    }

    func testEditingPhotosAfterOneFailedKeepsStoredPhotos() async throws {
        downloader.photos = ["u1": .init(image: .testPixel, metadata: ["assetIdentifier": "a1"])]
        let model = makeModel()
        var report: DiarySaveReport?
        model.onSaveFinished = { report = $0 }
        model.open(stored(photos: ["u1", "missing"]), editing: true)
        try await waitUntil { !model.isLoadingPhotos }
        XCTAssertEqual(model.photos.count, 1)
        model.finishPicking([photo("a1"), photo("b")], pickedIDs: ["a1", "b"])
        model.save()
        try await waitUntil { report != nil }
        XCTAssertEqual(saver.keptPhotos.first?.existing, ["u1", "missing"])
        XCTAssertTrue(saver.updated.isEmpty)
        XCTAssertEqual(report, .savedKeepingPhotos, "The user is told their photo change was not saved")
    }

    func testSavingAnUnchangedDiaryWritesNothing() async throws {
        downloader.photos = ["u1": .init(image: .testPixel, metadata: ["assetIdentifier": "a1"])]
        let model = makeModel()
        var started = false
        model.onSaveStarted = { _ in started = true }
        model.open(stored(photos: ["u1"]), editing: false)
        try await waitUntil { !model.isLoadingPhotos }
        model.beginEditing()

        XCTAssertTrue(model.save(), "The editor closes")
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertFalse(started)
        XCTAssertTrue(saver.updated.isEmpty)
        XCTAssertTrue(saver.keptPhotos.isEmpty)
    }

    func testTextOnlyEditKeepsStoredPhotoFilesWithoutWarning() async throws {
        downloader.photos = ["u1": .init(image: .testPixel, metadata: ["assetIdentifier": "a1"])]
        let model = makeModel()
        var report: DiarySaveReport?
        model.onSaveFinished = { report = $0 }
        model.open(stored(photos: ["u1"]), editing: true)
        try await waitUntil { !model.isLoadingPhotos }
        model.draft.content = "고친 내용"

        XCTAssertTrue(model.save())
        try await waitUntil { report != nil }
        XCTAssertEqual(report, .saved)
        XCTAssertEqual(saver.keptPhotos.first?.existing, ["u1"])
        XCTAssertEqual(saver.keptPhotos.first?.entry.content, "고친 내용")
        XCTAssertTrue(saver.updated.isEmpty, "Untouched photos are not compressed and uploaded again")
    }

    func testStoredDiaryShowsPlaceholdersThenItsPhotoPlace() async throws {
        downloader.photos = [
            "u1": .init(image: .testPixel, metadata: ["assetIdentifier": "a1", "location": "37.51, 126.99"]),
            "u2": .init(image: .testPixel, metadata: ["assetIdentifier": "a2"]),
        ]
        locating.names = ["37.51, 126.99": "한강공원"]
        var entry = stored(photos: ["u1", "u2"])
        entry.useMetadataLocation = true
        let model = makeModel()
        model.open(entry, editing: false)
        XCTAssertEqual(model.loadingPhotoCount, 2, "One placeholder per stored photo")
        try await waitUntil { model.placeName == "한강공원" }
        XCTAssertEqual(model.loadingPhotoCount, 0)
        XCTAssertTrue(model.draft.useMetadataLocation)
    }

    func testEditingSignedOutAsksToSignIn() {
        saver.userID = nil
        let model = makeModel()
        model.open(stored(), editing: true)
        XCTAssertFalse(model.save())
        XCTAssertEqual(model.notice, .signInRequired)
    }

    func testEditingDoesNotReplaceStoredPlaceWithCurrentOne() async throws {
        locating.coordinate = DiaryCoordinate(latitude: 1, longitude: 2)
        let model = makeModel()
        model.open(stored(), editing: true)
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(model.draft.currentLocationInfo, "37.5, 127.0")
        XCTAssertEqual(locating.coordinateRequests, 0)
    }
}

final class DiaryDraftTests: XCTestCase {
    func testConditionsKeepStoredValuesInPreviousOrder() {
        XCTAssertEqual(DiaryConditions.emotions.map(\.value), [
            "Smiling face with smiling eyes", "Grinning face", "Neutral face", "Disappointed but relieved face",
            "Persevering face", "Loudly crying face", "Pouting face", "Sleeping face", "Face screaming in fear",
            "Face vomiting", "Face with medical mask",
        ])
        XCTAssertEqual(DiaryConditions.weathers.map(\.value), [
            "u_sun", "u_cloud-sun", "u_clouds", "fi_wind", "u_cloud-showers-heavy", "u_moon", "u_cloud-moon",
            "u_rainbow", "u_snowflake", "u_thunderstorm",
        ])
        XCTAssertEqual(DiaryConditions.emotionLabel("Smiling face with smiling eyes"), "좋음")
        XCTAssertEqual(DiaryConditions.weatherLabel("u_thunderstorm"), "번개")
        XCTAssertNil(DiaryConditions.emotionLabel(""))
    }

    func testCoordinateReadsStoredText() {
        XCTAssertEqual(DiaryCoordinate(stored: "37.5665, 126.978"), DiaryCoordinate(latitude: 37.5665, longitude: 126.978))
        XCTAssertEqual(DiaryCoordinate(latitude: 37.5665, longitude: 126.978).stored, "37.5665, 126.978")
        XCTAssertNil(DiaryCoordinate(stored: "Unknown"))
        XCTAssertNil(DiaryCoordinate(stored: ""))
        XCTAssertNil(DiaryCoordinate(stored: nil))
    }

    func testNewEntryKeepsPreviousStoredShape() {
        var draft = DiaryDraft(date: DateFormatter.yyyyMMddHHmmss.date(from: "2026-09-30 21:00:00 +0900")!)
        draft.title = "t"
        let entry = draft.newEntry(weather: nil)
        XCTAssertEqual(entry.imageURL, [])
        XCTAssertEqual(entry.currentLocationInfo, "", "No place was stored as an empty string")
        XCTAssertFalse(entry.useMetadataLocation)
        XCTAssertNil(entry.id)
        XCTAssertNil(entry.weatherDescription)
        XCTAssertEqual(DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString), draft.date)
    }

    func testPickerMergeKeepsPhotosItCannotShow() {
        struct P: Equatable { let id: String?; let name: String }
        let current = [P(id: nil, name: "legacy"), P(id: "a", name: "a"), P(id: "b", name: "b")]
        let merged = DiaryPhotoPicking.merge(current: current, picked: [P(id: "b", name: "b2"), P(id: "c", name: "c")],
                                             pickedIDs: ["b", "c"]) { $0.id }
        XCTAssertEqual(merged.map(\.name), ["legacy", "b", "c"])
        XCTAssertEqual(DiaryPhotoPicking.pickerLimit(current: current) { $0.id }, 2)
        XCTAssertEqual(DiaryPhotoPicking.pickerLimit(current: [P]()) { $0.id }, 3)

        // Three photos the picker cannot show fill the limit; nothing picked may be added past it.
        let full = [P(id: nil, name: "1"), P(id: nil, name: "2"), P(id: nil, name: "3")]
        XCTAssertEqual(DiaryPhotoPicking.pickerLimit(current: full) { $0.id }, 0)
        XCTAssertEqual(DiaryPhotoPicking.merge(current: full, picked: [P(id: "x", name: "x")], pickedIDs: ["x"]) { $0.id }.map(\.name),
                       ["1", "2", "3"])
    }
}

// MARK: - Fakes

private extension UIImage {
    static let testPixel = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
        UIColor.systemPurple.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
}

@MainActor
final class FakeDraftStore: DiaryDraftStoring {
    /// The new diary's writing.
    var stored: StoredDiaryDraft?
    /// The changes kept for a stored diary.
    var storedEdit: StoredDiaryDraft?

    func load(diaryID: String?) -> StoredDiaryDraft? {
        diaryID == nil ? stored : (storedEdit?.diaryID == diaryID ? storedEdit : nil)
    }

    func save(_ draft: StoredDiaryDraft) {
        if draft.diaryID == nil { stored = draft } else { storedEdit = draft }
    }

    func clear(diaryID: String?) {
        if diaryID == nil { stored = nil } else if storedEdit?.diaryID == diaryID { storedEdit = nil }
    }

    func clearAll() {
        stored = nil
        storedEdit = nil
    }

    private var saving: [StoredDiaryDraft] = []

    func setSaving(_ isSaving: Bool, _ draft: StoredDiaryDraft) {
        saving.removeAll { $0 == draft }
        if isSaving { saving.append(draft) }
    }

    func isBeingSaved(_ draft: StoredDiaryDraft) -> Bool { saving.contains(draft) }
}

@MainActor
private final class RecordingDiarySaving: DiarySaving {
    struct Update {
        let entry: DiaryEntry
        let diaryID: String
        let expectedUserID: String
        let existing: [String]
        let uploads: [DiaryImageUpload]
        var slots: [String] = []
        var unreadable = 0
    }

    var userID: String? = "user-a"
    var outcome: Result<DiarySaveOutcome, Error> = .success(.saved)
    /// What an update that leaves the photos alone ends with.
    var keepingOutcome: Result<DiarySaveOutcome, Error> = .success(.savedKeepingPhotos)
    private(set) var created: [DiaryEntry] = []
    private(set) var createdUploads: [[DiaryImageUpload]] = []
    private(set) var updated: [Update] = []
    private(set) var keptPhotos: [Update] = []

    var currentUserID: String? { userID }

    func create(_ entry: DiaryEntry, images uploads: [DiaryImageUpload], unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        created.append(entry)
        createdUploads.append(uploads)
        if holdsCreate {
            heldCreate = completion
        } else {
            completion(outcome)
        }
    }

    /// Saves that end only when the test ends them, to look at what happens while a save runs.
    var holdsCreate = false
    private(set) var heldCreate: ((Result<DiarySaveOutcome, Error>) -> Void)?
    var holdsKeeping = false
    private(set) var heldKeeping: ((Result<DiarySaveOutcome, Error>) -> Void)?

    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String, existingImageURLs: [String],
                images uploads: [DiaryImageUpload], unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        updated.append(Update(entry: entry, diaryID: diaryID, expectedUserID: expectedUserID,
                              existing: existingImageURLs, uploads: uploads))
        completion(outcome)
    }

    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String, existingImageURLs: [String],
                photos: [DiaryPhotoSlot], unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        let slots = photos.map { slot -> String in
            switch slot {
            case .stored(let url): return "stored:\(url)"
            case .new(let upload): return "new:\(upload.assetIdentifier)"
            }
        }
        updated.append(Update(entry: entry, diaryID: diaryID, expectedUserID: expectedUserID,
                              existing: existingImageURLs, uploads: [], slots: slots, unreadable: unreadablePhotoCount))
        completion(outcome)
    }

    func updateKeepingPhotos(_ entry: DiaryEntry, diaryID: String, expectedUserID: String, existingImageURLs: [String],
                             completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        keptPhotos.append(Update(entry: entry, diaryID: diaryID, expectedUserID: expectedUserID,
                                 existing: existingImageURLs, uploads: []))
        if holdsKeeping {
            heldKeeping = completion
        } else {
            completion(keepingOutcome)
        }
    }
}

@MainActor
private final class FakePhotoDownloader: DiaryPhotoDownloading {
    var photos: [String: DownloadedDiaryPhoto] = [:]
    var delays: [String: UInt64] = [:]
    var hanging: Set<String> = []

    func download(_ url: String) async -> DownloadedDiaryPhoto? {
        if hanging.contains(url) {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
        if let delay = delays[url] {
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
        }
        return photos[url]
    }
}

@MainActor
private final class FakeWeatherLooking: DiaryWeatherLooking {
    var result: Result<WeatherResponse, WeatherError> = .failure(.unavailable)
    var hangs = false
    private(set) var lookups = 0

    func currentWeather() async -> Result<WeatherResponse, WeatherError> {
        lookups += 1
        if hangs { try? await Task.sleep(nanoseconds: 60_000_000_000) }
        return result
    }

    func attribution() async -> WeatherAttribution? { nil }
}

@MainActor
private final class FakeLocating: DiaryLocating {
    var coordinate: DiaryCoordinate?
    var names: [String: String] = [:]
    var nameDelay: UInt64 = 0
    private(set) var coordinateRequests = 0

    func currentCoordinate() async -> DiaryCoordinate? {
        coordinateRequests += 1
        return coordinate
    }

    func placeName(for coordinate: DiaryCoordinate) async -> String? {
        if nameDelay > 0 { try? await Task.sleep(nanoseconds: nameDelay * 1_000_000) }
        return names[coordinate.stored]
    }
}
