import Foundation
import Observation
import UIKit

/// A photo in the editor, picked from the library or downloaded from a stored diary, with the metadata saving stores.
struct EditorPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let assetIdentifier: String?
    /// Stored as the photo library gave it ("2026-09-30 09:12:00 +0000"), or "Unknown" for stored photos without it.
    let captureTime: String?
    /// "lat, lon", or "Unknown" for stored photos without it.
    let location: String?
    /// Set for a photo downloaded from the stored diary: saving keeps its file instead of uploading it again.
    var storedURL: String? = nil

    var coordinate: DiaryCoordinate? { DiaryCoordinate(stored: location) }
    var captureDate: Date? { captureTime.flatMap(DateFormatter.yyyyMMddHHmmss.date(from:)) }
}

struct DownloadedDiaryPhoto {
    let image: UIImage
    let metadata: [String: String]?
}

@MainActor
protocol DiaryPhotoDownloading {
    func download(_ url: String) async -> DownloadedDiaryPhoto?
}

/// Apple Weather's mark and legal page, which must be shown wherever WeatherKit data is shown.
struct WeatherAttribution: Equatable {
    let lightMark: URL
    let darkMark: URL
    let legalPage: URL
}

@MainActor
protocol DiaryWeatherLooking {
    func currentWeather() async -> Result<WeatherResponse, WeatherError>
    func attribution() async -> WeatherAttribution?
}

@MainActor
protocol DiaryLocating {
    /// Nil when location is off or not found in time.
    func currentCoordinate() async -> DiaryCoordinate?
    func placeName(for coordinate: DiaryCoordinate) async -> String?
}

/// How a save ended, for the screen that opened the editor (the editor is already closed by then).
/// What a save tells when it starts: the day the diary is for, and whether the diary is new.
struct DiarySaveStart: Equatable {
    let day: Date
    let isNew: Bool
}

enum DiarySaveReport: Equatable {
    case saved
    case savedWithMissingPhotos(Int)
    case savedKeepingPhotos
    case failed(isUpdate: Bool)
}

@MainActor
@Observable
final class DiaryEditorViewModel {
    enum Mode: Equatable {
        case compose
        case edit
        case read
    }

    enum WeatherState: Equatable {
        /// Not a diary for today: current weather does not describe it.
        case notToday
        case loading
        case loaded(description: String, celsius: Double)
        case failed(WeatherError)
    }

    enum Notice: Equatable {
        case titleMissing
        case signInRequired
        case photoLimitReached
        case photosStillLoading
        /// Picked photos that could not be read, e.g. not downloaded from iCloud.
        case photosNotLoaded(Int)
        /// Writing that was not saved before was brought back; its photos (so many) have to be picked again.
        case draftRestored(photoCount: Int)
        /// Changes to this stored diary that were not saved before were brought back.
        case editRestored(photoCount: Int)
    }

    /// Asked after picking a photo that has a place: add that place to the diary?
    struct PhotoPlaceQuestion: Equatable {
        let placeName: String
    }

    private(set) var mode: Mode = .compose
    var draft: DiaryDraft {
        didSet { keepDraft() }
    }
    private(set) var photos: [EditorPhoto] = [] {
        didSet { keepDraft() }
    }
    /// Photos still arriving, each shown as a placeholder until all of them are in.
    private(set) var loadingPhotoCount = 0
    private(set) var weather: WeatherState = .notToday
    private(set) var attribution: WeatherAttribution?
    private(set) var isSaving = false
    private(set) var placeName: String?
    var notice: Notice?
    var photoPlaceQuestion: PhotoPlaceQuestion?
    /// "작성을 그만할까요?" (mockup 28), from the close button or a swipe down.
    var showsDiscardConfirmation = false

    var onSaveStarted: ((DiarySaveStart) -> Void)?
    var onSaveFinished: ((DiarySaveReport) -> Void)?

    private let saver: any DiarySaving
    private let downloader: any DiaryPhotoDownloading
    private let weatherLooking: any DiaryWeatherLooking
    private let locating: any DiaryLocating
    private let calendar: Calendar
    private let now: () -> Date
    /// Keeps the writing of a new diary on the device; nil where nothing is kept (tests, previews).
    private let drafts: (any DiaryDraftStoring)?
    /// The writing was given up or saved: nothing is kept any more.
    private var isDraftSettled = false
    /// Who is writing, fixed when the writing starts. What is kept is kept for this account, also when the
    /// app signs out or another account signs in while the editor is open.
    private var draftUserID: String?

    private var entry: DiaryEntry?
    private var editingUserID: String?
    private var existingImageURLs: [String] = []
    private var existingPhotoLoad = ExistingPhotoLoad(expected: 0)
    private var initialDraft: DiaryDraft
    private var photosChanged = false
    private var weatherLookup: Result<WeatherResponse, WeatherError>?
    private var weatherTask: Task<Void, Never>?
    private var placeTask: Task<Void, Never>?
    private var placeQuestionTask: Task<Void, Never>?
    /// Photos picked but not yet loaded: saving now would leave them out.
    private var isPickingPhotos = false
    private var loadGeneration = 0

    init(saver: any DiarySaving, downloader: any DiaryPhotoDownloading, weather: any DiaryWeatherLooking,
         locating: any DiaryLocating, calendar: Calendar, now: @escaping () -> Date,
         drafts: (any DiaryDraftStoring)? = nil) {
        self.drafts = drafts
        self.saver = saver
        self.downloader = downloader
        self.weatherLooking = weather
        self.locating = locating
        self.calendar = calendar
        self.now = now
        let draft = DiaryDraft(date: now())
        self.draft = draft
        initialDraft = draft
    }

    // MARK: - Opening

    /// `day` is a day picked before opening (the calendar's selected day). The diary is written for it at the
    /// current time of day, like a date chosen in the editor. Today, a day to come or no day means now.
    func startComposing(on day: Date? = nil) {
        mode = .compose
        isDraftSettled = false
        draftUserID = saver.currentUserID
        let fresh = DiaryDraft(date: composeDate(for: day))
        // Read before the draft is set: setting it stores it, and an empty one clears what was kept.
        let kept = drafts?.load(diaryID: nil)
        initialDraft = fresh
        if let kept, !kept.isEmpty, kept.belongs(to: draftUserID) {
            // Writing left unsaved (the app was closed, or the save failed) comes back as it was, with its own day.
            var restored = fresh
            restored.title = kept.title
            restored.content = kept.content
            restored.date = min(kept.date, now())
            restored.emotion = kept.emotion
            restored.weather = kept.weather
            draft = restored
            notice = .draftRestored(photoCount: kept.photoCount)
        } else {
            // Another account's writing is not shown, and not kept either.
            draft = fresh
        }
        refreshWeather()
        Task { [weak self] in
            guard let self, let coordinate = await locating.currentCoordinate() else { return }
            // Kept by the draft only; it does not make the diary count as changed.
            draft.currentLocationInfo = coordinate.stored
            initialDraft.currentLocationInfo = coordinate.stored
        }
        loadAttribution()
    }

    private func composeDate(for day: Date?) -> Date {
        let now = now()
        guard let day, day < now, !calendar.isDate(day, inSameDayAs: now) else { return now }
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
    }

    func open(_ entry: DiaryEntry, editing: Bool) {
        // Nothing is kept while the stored diary is being put on screen.
        isDraftSettled = true
        self.entry = entry
        mode = editing ? .edit : .read
        editingUserID = saver.currentUserID
        draftUserID = editingUserID
        draft = DiaryDraft(entry: entry)
        initialDraft = draft
        existingImageURLs = entry.imageURL ?? []
        loadStoredPhotos(existingImageURLs)
        isDraftSettled = false
        if editing { restoreKeptChanges() }
        refreshPlaceName()
    }

    /// Called when the writing is given up ("나가기"): what was kept goes too.
    func discardDraft() {
        isDraftSettled = true
        switch mode {
        case .compose: drafts?.clear(diaryID: nil)
        case .edit: if let diaryID = entry?.id { drafts?.clear(diaryID: diaryID) }
        case .read: break
        }
    }

    /// Every change to the writing is kept, so closing the app or a failed save does not lose it:
    /// a new diary's writing, or what was changed in a stored diary.
    private func keepDraft() {
        guard !isDraftSettled, let drafts, isWriterStillSignedIn() else { return }
        switch mode {
        case .compose:
            let kept = keptDraft(diaryID: nil, photoCount: photos.count)
            if kept.isEmpty { drafts.clear(diaryID: nil) } else { drafts.save(kept) }
        case .edit:
            guard let diaryID = entry?.id else { return }
            // Only changed writing is kept; an edit that changed nothing, or only photos, has nothing to bring back.
            if hasSameWriting(draft, initialDraft) {
                drafts.clear(diaryID: diaryID)
            } else {
                drafts.save(keptDraft(diaryID: diaryID, photoCount: photos.filter { $0.storedURL == nil }.count))
            }
        case .read:
            break
        }
    }

    private func keptDraft(diaryID: String?, photoCount: Int) -> StoredDiaryDraft {
        StoredDiaryDraft(title: draft.title, content: draft.content, date: draft.date, emotion: draft.emotion,
                         weather: draft.weather, photoCount: photoCount, userID: draftUserID, diaryID: diaryID)
    }

    /// After a sign-out or an account switch nothing more is kept: what was kept stays the writer's as it was,
    /// and is never rewritten as nobody's or the next account's.
    private func isWriterStillSignedIn() -> Bool {
        let current = saver.currentUserID
        if current == draftUserID { return true }
        // Writing started before any account existed: the account made since (saving makes one) is the writer's.
        if draftUserID == nil, let current {
            draftUserID = current
            return true
        }
        return false
    }

    private func hasSameWriting(_ lhs: DiaryDraft, _ rhs: DiaryDraft) -> Bool {
        lhs.title == rhs.title && lhs.content == rhs.content && lhs.date == rhs.date
            && lhs.emotion == rhs.emotion && lhs.weather == rhs.weather
    }

    /// Changes to this diary that were not saved (the app was closed, or the save failed) come back.
    /// Changes to its photos are not kept: the stored photos are shown as they are.
    private func restoreKeptChanges() {
        // Reading may have been opened under another account than the one editing now.
        draftUserID = saver.currentUserID
        guard let diaryID = entry?.id, let userID = draftUserID,
              let kept = drafts?.load(diaryID: diaryID), kept.userID == userID else { return }
        var restored = draft
        restored.title = kept.title
        restored.content = kept.content
        restored.date = min(kept.date, now())
        restored.emotion = kept.emotion
        restored.weather = kept.weather
        guard !hasSameWriting(restored, draft) else { return }
        draft = restored
        notice = .editRestored(photoCount: kept.photoCount)
    }

    /// The pencil of the read screen: the same diary becomes editable in place.
    func beginEditing() {
        guard mode == .read else { return }
        mode = .edit
        restoreKeptChanges()
    }

    var isEditable: Bool { mode != .read }

    var hasChanges: Bool { isEditable && (draft != initialDraft || photosChanged) }

    var isToday: Bool { calendar.isDate(draft.date, inSameDayAs: now()) }

    // MARK: - Date and weather

    func selectDate(_ date: Date) {
        guard isEditable else { return }
        draft.date = date
        if mode == .compose { refreshWeather() }
    }

    /// Current weather is shown only while writing a new diary for today, as before; a stored diary keeps its own.
    private func refreshWeather() {
        weatherTask?.cancel()
        guard isToday else {
            weather = .notToday
            return
        }
        if let weatherLookup {
            show(weatherLookup)
            return
        }
        weather = .loading
        weatherTask = Task { [weak self] in
            guard let self else { return }
            let result = await weatherLooking.currentWeather()
            guard !Task.isCancelled else { return }
            weatherLookup = result
            if isToday { show(result) }
        }
    }

    private func show(_ result: Result<WeatherResponse, WeatherError>) {
        switch result {
        case .success(let response):
            weather = .loaded(description: response.weather.first?.description ?? "날씨정보 없음", celsius: response.main.temp)
        case .failure(let error):
            weather = .failed(error)
        }
    }

    private func loadAttribution() {
        Task { [weak self] in
            guard let self else { return }
            attribution = await weatherLooking.attribution()
        }
    }

    // MARK: - Photos

    /// The picker shows these as already selected, in order.
    var pickerSelection: [String] { photos.compactMap(\.assetIdentifier) }
    var pickerLimit: Int { DiaryPhotoPicking.pickerLimit(current: photos) { $0.assetIdentifier } }

    var isLoadingPhotos: Bool { loadingPhotoCount > 0 }

    /// False while photos are still arriving (the picker could not show them as selected, and the arriving photos
    /// would replace what it returns), and when photos the picker cannot show fill the limit (0 would mean no limit).
    func canPickPhotos() -> Bool {
        guard !isLoadingPhotos else {
            notice = .photosStillLoading
            return false
        }
        guard pickerLimit > 0 else {
            notice = .photoLimitReached
            return false
        }
        return true
    }

    /// `pickedIDs` are what the picker returned; only photos not already in the editor are loaded.
    func pickingStarted(pickedIDs: [String]) {
        let current = Set(pickerSelection)
        loadingPhotoCount = pickedIDs.filter { !current.contains($0) }.count
        isPickingPhotos = true
    }

    /// `picked` are the photos the picker returned, in selection order; `pickedIDs` includes photos it could not load.
    func finishPicking(_ picked: [EditorPhoto], pickedIDs: [String]) {
        let expectedNew = loadingPhotoCount
        loadingPhotoCount = 0
        isPickingPhotos = false
        // A picked photo that could not be read is not added; the user is told instead of it silently missing.
        if picked.count < expectedNew { notice = .photosNotLoaded(expectedNew - picked.count) }
        let merged = DiaryPhotoPicking.merge(current: photos, picked: picked, pickedIDs: pickedIDs) { $0.assetIdentifier }
        if merged.map(\.id) != photos.map(\.id) { photosChanged = true }
        photos = merged
        dropPlaceQuestionIfItsPhotoIsGone()
        forgetPlaceIfItsPhotoIsGone()
        // Asked once: a diary that already has its photo's place keeps it.
        guard !picked.isEmpty, !draft.useMetadataLocation, let placed = photos.first(where: { $0.coordinate != nil }),
              let coordinate = placed.coordinate else { return }
        placeQuestionTask = Task { [weak self] in
            guard let self, let name = await locating.placeName(for: coordinate) else { return }
            // The photo may have been removed or picked away while its place was looked up.
            guard !Task.isCancelled, photos.contains(where: { $0.id == placed.id }), !draft.useMetadataLocation else { return }
            photoPlaceQuestion = PhotoPlaceQuestion(placeName: name)
        }
    }

    /// Yes stores the photos' place (`useMetadataLocation`), shown as a short line; the date is left as it is.
    func answerPhotoPlace(addPlace: Bool) {
        guard photoPlaceQuestion != nil else { return }
        photoPlaceQuestion = nil
        // A photo with a place must still be there for its place to be added.
        draft.useMetadataLocation = addPlace && photos.contains { $0.coordinate != nil }
        refreshPlaceName()
    }

    func removePlace() {
        guard isEditable else { return }
        draft.useMetadataLocation = false
        refreshPlaceName()
    }

    func removePhoto(_ id: EditorPhoto.ID) {
        guard isEditable, let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos.remove(at: index)
        photosChanged = true
        dropPlaceQuestionIfItsPhotoIsGone()
        forgetPlaceIfItsPhotoIsGone()
    }

    /// A question still being prepared, or shown, for a photo no longer in the editor is dropped.
    private func dropPlaceQuestionIfItsPhotoIsGone() {
        placeQuestionTask?.cancel()
        placeQuestionTask = nil
        if photoPlaceQuestion != nil, !photos.contains(where: { $0.coordinate != nil }) {
            photoPlaceQuestion = nil
        }
    }

    private func forgetPlaceIfItsPhotoIsGone() {
        if draft.useMetadataLocation, !isLoadingPhotos, placeCoordinate == nil {
            draft.useMetadataLocation = false
        }
        refreshPlaceName()
    }

    private func loadStoredPhotos(_ urls: [String]) {
        loadGeneration += 1
        let generation = loadGeneration
        photos = []
        existingPhotoLoad = ExistingPhotoLoad(expected: urls.count)
        guard !urls.isEmpty else { return }
        loadingPhotoCount = urls.count
        var slots = [EditorPhoto?](repeating: nil, count: urls.count)
        for (index, url) in urls.enumerated() {
            Task { [weak self] in
                guard let self else { return }
                let downloaded = await downloader.download(url)
                guard generation == loadGeneration else { return }
                if let downloaded {
                    existingPhotoLoad.photoArrived()
                    let metadata = downloaded.metadata
                    slots[index] = EditorPhoto(image: downloaded.image, assetIdentifier: metadata?["assetIdentifier"],
                                               captureTime: metadata?["captureTime"] ?? "Unknown",
                                               location: metadata?["location"] ?? "Unknown", storedURL: url)
                } else {
                    // A photo that failed to load is not shown; saving then leaves the stored photos as they are.
                    existingPhotoLoad.photoFailed()
                }
                if existingPhotoLoad.isSettled {
                    photos = slots.compactMap { $0 }
                    loadingPhotoCount = 0
                    refreshPlaceName()
                }
            }
        }
    }

    // MARK: - Place

    /// The photos' place, when the user chose to add it. Where the diary was written is stored but not shown.
    var placeCoordinate: DiaryCoordinate? {
        draft.useMetadataLocation ? photos.lazy.compactMap(\.coordinate).first : nil
    }

    private func refreshPlaceName() {
        placeTask?.cancel()
        guard let coordinate = placeCoordinate else {
            placeName = nil
            return
        }
        placeTask = Task { [weak self] in
            guard let self else { return }
            let name = await locating.placeName(for: coordinate)
            guard !Task.isCancelled else { return }
            placeName = name
        }
    }

    // MARK: - Saving

    /// Starts saving and returns true when the editor can close; the save finishes in the background.
    @discardableResult
    func save() -> Bool {
        guard isEditable, !isSaving else { return false }
        guard !draft.isTitleMissing else {
            notice = .titleMissing
            return false
        }
        guard !isPickingPhotos else {
            notice = .photosStillLoading
            return false
        }
        switch mode {
        case .compose:
            let stamp = DiaryWeatherStamp.forDiary(on: draft.date, now: now(), calendar: calendar, lookup: weatherLookup)
            let newEntry = draft.newEntry(weather: stamp)
            begin(isNew: true)
            let photos = photos
            Task {
                let prepared = await Self.encode(photos)
                saver.create(newEntry, images: prepared.uploads, unreadablePhotoCount: prepared.unreadable) { [self] result in
                    finish(result, isUpdate: false)
                }
            }
        case .edit:
            guard let entry, let diaryID = entry.id else { return false }
            guard let editingUserID else {
                notice = .signInRequired
                return false
            }
            // Nothing to write: close without touching the stored diary (the pencil and 저장 share a place).
            guard hasChanges else { return true }
            let updated = draft.applied(to: entry)
            let existing = existingImageURLs
            begin(isNew: false)
            // Untouched photos keep their stored files instead of being compressed and uploaded again.
            guard photosChanged else {
                saver.updateKeepingPhotos(updated, diaryID: diaryID, expectedUserID: editingUserID,
                                          existingImageURLs: existing) { [self] result in
                    finish(result, isUpdate: true, photosUntouched: true)
                }
                return true
            }
            // Photos not all downloaded (still loading or failed) are not in the editor; replacing would delete them.
            guard existingPhotoLoad.allLoaded else {
                saver.updateKeepingPhotos(updated, diaryID: diaryID, expectedUserID: editingUserID,
                                          existingImageURLs: existing) { [self] result in
                    finish(result, isUpdate: true)
                }
                return true
            }
            let photos = photos
            Task {
                let prepared = await Self.slots(photos)
                saver.update(updated, diaryID: diaryID, expectedUserID: editingUserID, existingImageURLs: existing,
                             photos: prepared.slots, unreadablePhotoCount: prepared.unreadable) { [self] result in
                    finish(result, isUpdate: true)
                }
            }
        case .read:
            return false
        }
        return true
    }

    private func begin(isNew: Bool) {
        isSaving = true
        weatherTask?.cancel()
        onSaveStarted?(DiarySaveStart(day: draft.date, isNew: isNew))
    }

    private func finish(_ result: Result<DiarySaveOutcome, Error>, isUpdate: Bool, photosUntouched: Bool = false) {
        isSaving = false
        let report: DiarySaveReport
        switch result {
        case .success(.saved): report = .saved
        case .success(.savedWithMissingPhotos(let count)): report = .savedWithMissingPhotos(count)
        // Keeping photos nobody changed is the expected result, not something to warn about.
        case .success(.savedKeepingPhotos): report = photosUntouched ? .saved : .savedKeepingPhotos
        case .failure(let error):
            print("Error saving diary: \(type(of: error))")
            report = .failed(isUpdate: isUpdate)
        }
        // Saved writing is kept no more; after a failure it stays for the next try.
        if report != .failed(isUpdate: isUpdate) {
            isDraftSettled = true
            if isUpdate {
                if let diaryID = entry?.id { drafts?.clear(diaryID: diaryID) }
            } else {
                drafts?.clear(diaryID: nil)
            }
        }
        onSaveFinished?(report)
    }

    /// Stored photos keep their file (even ones saved without a library identifier); only new photos are encoded.
    nonisolated static func slots(_ photos: [EditorPhoto]) async -> (slots: [DiaryPhotoSlot], unreadable: Int) {
        let newPhotos = photos.filter { $0.storedURL == nil }
        let encoded = await encode(newPhotos)
        var uploads = encoded.uploads.makeIterator()
        var slots: [DiaryPhotoSlot] = []
        for photo in photos {
            if let url = photo.storedURL {
                slots.append(.stored(url: url))
            } else if photo.assetIdentifier != nil, let upload = uploads.next() {
                slots.append(.new(upload))
            }
        }
        return (slots, encoded.unreadable)
    }

    /// JPEG at the previous quality, off the main thread. A photo without a library identifier cannot be uploaded.
    nonisolated static func encode(_ photos: [EditorPhoto]) async -> (uploads: [DiaryImageUpload], unreadable: Int) {
        await Task.detached(priority: .userInitiated) {
            var uploads: [DiaryImageUpload] = []
            var unreadable = 0
            for photo in photos {
                guard let assetIdentifier = photo.assetIdentifier,
                      let data = photo.image.jpegData(compressionQuality: 0.4) else {
                    unreadable += 1
                    continue
                }
                uploads.append(DiaryImageUpload(data: data, assetIdentifier: assetIdentifier,
                                                captureTime: photo.captureTime, location: photo.location))
            }
            return (uploads, unreadable)
        }.value
    }
}
