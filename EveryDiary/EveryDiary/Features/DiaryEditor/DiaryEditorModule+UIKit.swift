import CoreLocation
import ImageIO
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import WeatherKit

@MainActor
enum DiaryEditorModule {
    static func makeEditor(saver: any DiarySaving) -> DiaryEditorHostingController {
        let viewModel = DiaryEditorViewModel(saver: saver, downloader: StoragePhotoDownloader(), weather: LiveDiaryWeather(),
                                             locating: LiveDiaryLocating(), calendar: .current, now: Date.init)
        return DiaryEditorHostingController(viewModel: viewModel)
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
    private var onStart: (([String]) -> Void)?
    private var onFinish: (([EditorPhoto], [String]) -> Void)?

    func pick(from presenter: UIViewController, selection: [String], limit: Int,
              onStart: @escaping ([String]) -> Void, onFinish: @escaping ([EditorPhoto], [String]) -> Void) {
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
            onStart?(ids)
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

    /// The capture time and place come from the photo library when the app may read it, otherwise from the file.
    /// A photo is never dropped for missing metadata (with limited access the library lookup finds nothing).
    private nonisolated static func load(_ result: PHPickerResult, id: String) async -> EditorPhoto? {
        let image: UIImage? = await withCheckedContinuation { continuation in
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
        guard let image else { return nil }
        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
            let location = asset.location.map { "\($0.coordinate.latitude), \($0.coordinate.longitude)" }
            return EditorPhoto(image: image, assetIdentifier: id, captureTime: asset.creationDate?.description, location: location)
        }
        let file = await fileMetadata(of: result)
        return EditorPhoto(image: image, assetIdentifier: id, captureTime: file.date?.description, location: file.location?.stored)
    }

    private nonisolated static func fileMetadata(of result: PHPickerResult) async -> (date: Date?, location: DiaryCoordinate?) {
        await withCheckedContinuation { continuation in
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                guard let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                continuation.resume(returning: (captureDate(properties), coordinate(properties)))
            }
        }
    }

    private nonisolated static func captureDate(_ properties: [CFString: Any]) -> Date? {
        guard let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXX"
            return formatter.date(from: text + offset)
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: text)
    }

    private nonisolated static func coordinate(_ properties: [CFString: Any]) -> DiaryCoordinate? {
        guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double else { return nil }
        let south = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S"
        let west = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W"
        return DiaryCoordinate(latitude: south ? -latitude : latitude, longitude: west ? -longitude : longitude)
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
