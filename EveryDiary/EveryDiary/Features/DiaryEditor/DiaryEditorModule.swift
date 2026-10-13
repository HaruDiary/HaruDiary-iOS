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
    /// `drafts` is shared by every editor, so one editor knows about a save another one started.
    static func makeViewModel(saver: any DiarySaving, drafts: (any DiaryDraftStoring)?) -> DiaryEditorViewModel {
        DiaryEditorViewModel(saver: saver, downloader: StoragePhotoDownloader(), weather: LiveDiaryWeather(),
                             locating: LiveDiaryLocating(), calendar: .current, now: Date.init,
                             drafts: drafts)
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

/// Place names for the photo place line, and the place of a stored photo from this device's photo library.
/// Nothing here leaves the device except the name lookup itself.
@MainActor
private final class LiveDiaryLocating: DiaryLocating {
    func placeName(for coordinate: DiaryCoordinate) async -> String? {
        // As the previous editor showed: the place's own name, otherwise its full address.
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        if let name = placemark.name { return name }
        guard let address = placemark.postalAddress else { return nil }
        let formatted = CNPostalAddressFormatter.string(from: address, style: .mailingAddress)
        return formatted.isEmpty ? nil : formatted
    }

    /// The iCloud Photos identifier finds the photo on any device with the same Apple ID; the library identifier
    /// finds it on the device that picked it. Without library access there is nothing to read.
    func photoCoordinate(cloudIdentifier: String?, assetIdentifier: String?) async -> DiaryCoordinate? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }
        var candidates: [String] = []
        if let cloudIdentifier,
           case .success(let local)? = PHPhotoLibrary.shared().localIdentifierMappings(for: [PHCloudIdentifier(stringValue: cloudIdentifier)]).values.first {
            candidates.append(local)
        }
        if let assetIdentifier { candidates.append(assetIdentifier) }
        guard !candidates.isEmpty,
              let location = PHAsset.fetchAssets(withLocalIdentifiers: candidates, options: nil).firstObject?.location else { return nil }
        return DiaryCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
}

// MARK: - Photo library

/// Loads photos picked with the system photo picker, with each photo's library identifier, capture time and
/// place. Saving stores the identifiers and capture time with the photo; the place stays on the device.
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
            var photo = EditorPhoto(image: image, assetIdentifier: id, captureTime: asset.creationDate?.description, location: location)
            photo.cloudIdentifier = cloudIdentifier(of: id)
            return photo
        }
        let file = fileMetadata(of: data)
        return EditorPhoto(image: image, assetIdentifier: id, captureTime: file.date?.description, location: file.location?.stored)
    }

    /// Nil for a photo that is not in iCloud Photos; such a photo's place can only be found on this device.
    private static func cloudIdentifier(of localIdentifier: String) -> String? {
        guard case .success(let cloud)? = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: [localIdentifier])[localIdentifier] else {
            return nil
        }
        return cloud.stringValue
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
