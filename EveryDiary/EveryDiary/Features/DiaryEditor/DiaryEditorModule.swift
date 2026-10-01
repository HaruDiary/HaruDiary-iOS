import Contacts
import CoreLocation
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WeatherKit

@MainActor
enum DiaryEditorModule {
    static func makeViewModel(saver: any DiarySaving) -> DiaryEditorViewModel {
        DiaryEditorViewModel(saver: saver, downloader: StoragePhotoDownloader(), weather: LiveDiaryWeather(),
                             locating: LiveDiaryLocating(), calendar: .current, now: Date.init)
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
        // As the previous editor showed: the place's own name, otherwise its full address.
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        if let name = placemark.name { return name }
        guard let address = placemark.postalAddress else { return nil }
        let formatted = CNPostalAddressFormatter.string(from: address, style: .mailingAddress)
        return formatted.isEmpty ? nil : formatted
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

/// Loads photos picked with the system photo picker, with each photo's library identifier, capture time and
/// place, which saving stores with the photo.
enum DiaryPhotoLoader {
    /// Asked once, so the capture time and place can be read from the library. The picker itself needs no
    /// permission, so a refusal does not stop the user from adding photos.
    static func requestLibraryAccessIfNeeded() async {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined else { return }
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// Loaded in parallel, returned in the order they were picked. A photo that cannot be read is left out.
    static func load(_ items: [PhotosPickerItem]) async -> [EditorPhoto] {
        await withTaskGroup(of: (Int, EditorPhoto?).self) { group in
            for (index, item) in items.enumerated() {
                guard let id = item.itemIdentifier else { continue }
                group.addTask { (index, await load(item, id: id)) }
            }
            var loaded: [(Int, EditorPhoto)] = []
            for await (index, photo) in group {
                if let photo { loaded.append((index, photo)) }
            }
            return loaded.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// The capture time and place come from the photo library when the app may read it, otherwise from the file.
    /// A photo is never dropped for missing metadata (with limited access the library lookup finds nothing).
    private static func load(_ item: PhotosPickerItem, id: String) async -> EditorPhoto? {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return nil }
        if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject {
            let location = asset.location.map { "\($0.coordinate.latitude), \($0.coordinate.longitude)" }
            return EditorPhoto(image: image, assetIdentifier: id, captureTime: asset.creationDate?.description, location: location)
        }
        let file = fileMetadata(of: data)
        return EditorPhoto(image: image, assetIdentifier: id, captureTime: file.date?.description, location: file.location?.stored)
    }

    private static func fileMetadata(of data: Data) -> (date: Date?, location: DiaryCoordinate?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return (nil, nil) }
        return (captureDate(properties), coordinate(properties))
    }

    private static func captureDate(_ properties: [CFString: Any]) -> Date? {
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

    private static func coordinate(_ properties: [CFString: Any]) -> DiaryCoordinate? {
        guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double else { return nil }
        let south = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S"
        let west = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W"
        return DiaryCoordinate(latitude: south ? -latitude : latitude, longitude: west ? -longitude : longitude)
    }
}
