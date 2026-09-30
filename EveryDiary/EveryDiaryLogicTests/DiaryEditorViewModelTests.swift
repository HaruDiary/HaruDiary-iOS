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

    private func makeModel() -> DiaryEditorViewModel {
        DiaryEditorViewModel(saver: saver, downloader: downloader, weather: weather, locating: locating,
                             calendar: calendar, now: { [today] in today })
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
        model.onSaveStarted = { events.append("start") }
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

    func testOnlyNewlyPickedPhotosShowPlaceholders() {
        let model = makeModel()
        model.startComposing()
        model.finishPicking([photo("a")], pickedIDs: ["a"])
        model.pickingStarted(pickedIDs: ["a", "b", "c"])
        XCTAssertEqual(model.loadingPhotoCount, 2)
        model.finishPicking([photo("a"), photo("b"), photo("c")], pickedIDs: ["a", "b", "c"])
        XCTAssertEqual(model.loadingPhotoCount, 0)
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

    func testEditingReuploadsLoadedPhotosInOrderAndKeepsOtherFields() async throws {
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
        XCTAssertEqual(update.uploads.map(\.assetIdentifier), ["a1", "a2", "new"])
        XCTAssertEqual(update.uploads.first?.captureTime, "t1")
        XCTAssertEqual(update.uploads[1].captureTime, "Unknown")
        XCTAssertEqual(update.uploads[1].location, "Unknown")
        XCTAssertEqual(update.entry.title, "고친 제목")
        XCTAssertEqual(update.entry.weatherDescription, "맑음")
        XCTAssertEqual(update.entry.currentLocationInfo, "37.5, 127.0")
        XCTAssertEqual(update.entry.userID, "user-a")
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
        model.onSaveStarted = { started = true }
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
private final class RecordingDiarySaving: DiarySaving {
    struct Update {
        let entry: DiaryEntry
        let diaryID: String
        let expectedUserID: String
        let existing: [String]
        let uploads: [DiaryImageUpload]
    }

    var userID: String? = "user-a"
    var outcome: Result<DiarySaveOutcome, Error> = .success(.saved)
    private(set) var created: [DiaryEntry] = []
    private(set) var createdUploads: [[DiaryImageUpload]] = []
    private(set) var updated: [Update] = []
    private(set) var keptPhotos: [Update] = []

    var currentUserID: String? { userID }

    func create(_ entry: DiaryEntry, images uploads: [DiaryImageUpload], unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        created.append(entry)
        createdUploads.append(uploads)
        completion(outcome)
    }

    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String, existingImageURLs: [String],
                images uploads: [DiaryImageUpload], unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        updated.append(Update(entry: entry, diaryID: diaryID, expectedUserID: expectedUserID,
                              existing: existingImageURLs, uploads: uploads))
        completion(outcome)
    }

    func updateKeepingPhotos(_ entry: DiaryEntry, diaryID: String, expectedUserID: String, existingImageURLs: [String],
                             completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        keptPhotos.append(Update(entry: entry, diaryID: diaryID, expectedUserID: expectedUserID,
                                 existing: existingImageURLs, uploads: []))
        completion(.success(.savedKeepingPhotos))
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
    private(set) var coordinateRequests = 0

    func currentCoordinate() async -> DiaryCoordinate? {
        coordinateRequests += 1
        return coordinate
    }

    func placeName(for coordinate: DiaryCoordinate) async -> String? {
        names[coordinate.stored]
    }
}
