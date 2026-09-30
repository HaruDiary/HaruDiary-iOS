import CoreLocation
import Photos
import PhotosUI
import UIKit
import WeatherKit

@MainActor
enum DiaryEditorModule {
    static func makeEditor(saver: any DiarySaving) -> DiaryEditorHostingController {
        let viewModel = DiaryEditorViewModel(saver: saver, downloader: StoragePhotoDownloader(), weather: LiveDiaryWeather(),
                                             locating: LiveDiaryLocating(), calendar: .current, now: Date.init)
        return DiaryEditorHostingController(viewModel: viewModel)
    }

    static func open(_ coordinate: DiaryCoordinate, in app: DiaryMapApp) {
        let maps = MapManager.shared
        switch app {
        case .apple: maps.openAppleMaps(latitude: coordinate.latitude, longitude: coordinate.longitude)
        case .google: maps.openGoogleMapsForPlace(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

// MARK: - Stored photos

@MainActor
private struct StoragePhotoDownloader: DiaryPhotoDownloading {
    func download(_ url: String) async -> DownloadedDiaryPhoto? {
        await withCheckedContinuation { continuation in
            FirebaseStorageManager.downloadImage(urlString: url) { image, metadata in
                continuation.resume(returning: image.map { DownloadedDiaryPhoto(image: $0, metadata: metadata) })
            }
        }
    }
}

// MARK: - Weather

@MainActor
private final class LiveDiaryWeather: DiaryWeatherLooking {
    private let service = WeatherService()

    func currentWeather() async -> Result<WeatherResponse, WeatherError> {
        await withCheckedContinuation { continuation in
            service.getWeather { continuation.resume(returning: $0) }
        }
    }

    func attribution() async -> WeatherAttribution? {
        guard let attribution = try? await WeatherKit.WeatherService.shared.attribution else { return nil }
        return WeatherAttribution(lightMark: attribution.combinedMarkLightURL, darkMark: attribution.combinedMarkDarkURL,
                                  legalPage: attribution.legalPageURL)
    }
}

// MARK: - Location

/// One location for a new diary, as the previous editor asked for when it opened. No alert when location is off.
@MainActor
private final class LiveDiaryLocating: NSObject, DiaryLocating, CLLocationManagerDelegate {
    private static let timeout: UInt64 = 10_000_000_000
    private let manager = CLLocationManager()
    private var waiting: [CheckedContinuation<DiaryCoordinate?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func currentCoordinate() async -> DiaryCoordinate? {
        switch manager.authorizationStatus {
        case .denied, .restricted: return nil
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: manager.requestLocation()
        }
        let timeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.timeout)
            self?.finish(nil)
        }
        defer { timeout.cancel() }
        return await withCheckedContinuation { waiting.append($0) }
    }

    func placeName(for coordinate: DiaryCoordinate) async -> String? {
        await withCheckedContinuation { continuation in
            MapManager.shared.getPlaceName(latitude: coordinate.latitude, longitude: coordinate.longitude) { name in
                continuation.resume(returning: name == "Unknown Location" ? nil : name)
            }
        }
    }

    private func finish(_ coordinate: DiaryCoordinate?) {
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume(returning: coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in self.finish(DiaryCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if !self.waiting.isEmpty { self.manager.requestLocation() }
            case .denied, .restricted:
                self.finish(nil)
            default:
                break
            }
        }
    }
}

// MARK: - Photo library

/// The system photo picker: up to three photos in selection order, with each photo's library identifier,
/// capture time and place, which saving stores with the photo.
@MainActor
final class DiaryPhotoLibraryPicker: NSObject, PHPickerViewControllerDelegate {
    private var onStart: (() -> Void)?
    private var onFinish: (([EditorPhoto], [String]) -> Void)?

    func pick(from presenter: UIViewController, selection: [String], limit: Int,
              onStart: @escaping () -> Void, onFinish: @escaping ([EditorPhoto], [String]) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            Task { @MainActor in
                switch status {
                case .authorized, .limited:
                    self.onStart = onStart
                    self.onFinish = onFinish
                    var configuration = PHPickerConfiguration(photoLibrary: .shared())
                    configuration.selectionLimit = limit
                    configuration.selection = .ordered
                    configuration.filter = .images
                    configuration.preselectedAssetIdentifiers = selection
                    let picker = PHPickerViewController(configuration: configuration)
                    picker.delegate = self
                    presenter.present(picker, animated: true)
                default:
                    Self.askForAccess(from: presenter)
                }
            }
        }
    }

    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor in
            picker.dismiss(animated: true)
            let ids = results.compactMap(\.assetIdentifier)
            onStart?()
            let photos = await withTaskGroup(of: (Int, EditorPhoto?).self) { group in
                for (index, result) in results.enumerated() {
                    guard let id = result.assetIdentifier else { continue }
                    group.addTask { (index, await Self.load(result, id: id)) }
                }
                var loaded: [(Int, EditorPhoto)] = []
                for await (index, photo) in group {
                    if let photo { loaded.append((index, photo)) }
                }
                // Loaded in parallel, kept in the order they were picked.
                return loaded.sorted { $0.0 < $1.0 }.map(\.1)
            }
            onFinish?(photos, ids)
        }
    }

    private nonisolated static func load(_ result: PHPickerResult, id: String) async -> EditorPhoto? {
        await withCheckedContinuation { continuation in
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage,
                      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
                    continuation.resume(returning: nil)
                    return
                }
                let location = asset.location.map { "\($0.coordinate.latitude), \($0.coordinate.longitude)" }
                continuation.resume(returning: EditorPhoto(image: image, assetIdentifier: id,
                                                           captureTime: asset.creationDate?.description, location: location))
            }
        }
    }

    private static func askForAccess(from presenter: UIViewController) {
        let alert = UIAlertController(title: "사진에 접근할 수 없어요",
                                      message: "일기에 사진을 넣으려면 설정에서 사진 접근을 허용해주세요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "설정", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        presenter.present(alert, animated: true)
    }
}
