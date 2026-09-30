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
    }

    /// Asked after picking a photo that has a place: add that place to the diary?
    struct PhotoPlaceQuestion: Equatable {
        let placeName: String
    }

    private(set) var mode: Mode = .compose
    var draft: DiaryDraft
    private(set) var photos: [EditorPhoto] = []
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

    var onSaveStarted: (() -> Void)?
    var onSaveFinished: ((DiarySaveReport) -> Void)?

    private let saver: any DiarySaving
    private let downloader: any DiaryPhotoDownloading
    private let weatherLooking: any DiaryWeatherLooking
    private let locating: any DiaryLocating
    private let calendar: Calendar
    private let now: () -> Date

    private var entry: DiaryEntry?
    private var editingUserID: String?
    private var existingImageURLs: [String] = []
    private var existingPhotoLoad = ExistingPhotoLoad(expected: 0)
    private var initialDraft: DiaryDraft
    private var photosChanged = false
    private var weatherLookup: Result<WeatherResponse, WeatherError>?
    private var weatherTask: Task<Void, Never>?
    private var placeTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(saver: any DiarySaving, downloader: any DiaryPhotoDownloading, weather: any DiaryWeatherLooking,
         locating: any DiaryLocating, calendar: Calendar, now: @escaping () -> Date) {
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

    func startComposing() {
        mode = .compose
        draft = DiaryDraft(date: now())
        initialDraft = draft
        refreshWeather()
        Task { [weak self] in
            guard let self, let coordinate = await locating.currentCoordinate() else { return }
            // Kept by the draft only; it does not make the diary count as changed.
            draft.currentLocationInfo = coordinate.stored
            initialDraft.currentLocationInfo = coordinate.stored
        }
        loadAttribution()
    }

    func open(_ entry: DiaryEntry, editing: Bool) {
        self.entry = entry
        mode = editing ? .edit : .read
        editingUserID = saver.currentUserID
        draft = DiaryDraft(entry: entry)
        initialDraft = draft
        existingImageURLs = entry.imageURL ?? []
        loadStoredPhotos(existingImageURLs)
        refreshPlaceName()
    }

    /// The pencil of the read screen: the same diary becomes editable in place.
    func beginEditing() {
        guard mode == .read else { return }
        mode = .edit
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

    /// False when the photos the picker cannot show already fill the limit: a picker limit of 0 would mean no limit.
    func canPickPhotos() -> Bool {
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
    }

    /// `picked` are the photos the picker returned, in selection order; `pickedIDs` includes photos it could not load.
    func finishPicking(_ picked: [EditorPhoto], pickedIDs: [String]) {
        loadingPhotoCount = 0
        let merged = DiaryPhotoPicking.merge(current: photos, picked: picked, pickedIDs: pickedIDs) { $0.assetIdentifier }
        if merged.map(\.id) != photos.map(\.id) { photosChanged = true }
        photos = merged
        forgetPlaceIfItsPhotoIsGone()
        // Asked once: a diary that already has its photo's place keeps it.
        guard !draft.useMetadataLocation, let coordinate = picked.lazy.compactMap(\.coordinate).first else { return }
        Task { [weak self] in
            guard let self, let name = await locating.placeName(for: coordinate) else { return }
            photoPlaceQuestion = PhotoPlaceQuestion(placeName: name)
        }
    }

    /// Yes stores the photos' place (`useMetadataLocation`), shown as a short line; the date is left as it is.
    func answerPhotoPlace(addPlace: Bool) {
        guard photoPlaceQuestion != nil else { return }
        photoPlaceQuestion = nil
        draft.useMetadataLocation = addPlace
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
        forgetPlaceIfItsPhotoIsGone()
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
                                               location: metadata?["location"] ?? "Unknown")
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
        switch mode {
        case .compose:
            let stamp = DiaryWeatherStamp.forDiary(on: draft.date, now: now(), calendar: calendar, lookup: weatherLookup)
            let newEntry = draft.newEntry(weather: stamp)
            begin()
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
            begin()
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
                let prepared = await Self.encode(photos)
                saver.update(updated, diaryID: diaryID, expectedUserID: editingUserID, existingImageURLs: existing,
                             images: prepared.uploads, unreadablePhotoCount: prepared.unreadable) { [self] result in
                    finish(result, isUpdate: true)
                }
            }
        case .read:
            return false
        }
        return true
    }

    private func begin() {
        isSaving = true
        weatherTask?.cancel()
        onSaveStarted?()
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
        onSaveFinished?(report)
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
