import UIKit

/// Gives the profile photo to the settings screens: at once when it is kept on the device, otherwise after
/// downloading it once. One loader lives as long as the app, so reopening settings shows the photo immediately.
@MainActor
final class ProfilePhotoLoader: ProfilePhotoStoring {
    private let files: ProfilePhotoFiles
    private let download: (URL) async throws -> Data
    private var shown: (url: URL, image: UIImage)?
    /// The photo the signed-in account shows, once the account is known.
    private var keptURL: URL?
    /// Goes up when the kept photo is dropped (sign-out, another account): a download started before that
    /// is for the previous account and must not be kept when it arrives late.
    private var generation = 0

    init(files: ProfilePhotoFiles,
         download: @escaping (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 }) {
        self.files = files
        self.download = download
    }

    /// The photo when it is already on the device; nil means it has to be loaded.
    func image(for url: URL) -> UIImage? {
        if let shown, shown.url == url { return shown.image }
        guard let data = files.data(for: url), let image = UIImage(data: data) else { return nil }
        shown = (url, image)
        return image
    }

    func load(_ url: URL) async -> UIImage? {
        if let image = image(for: url) { return image }
        let started = generation
        guard let data = try? await download(url), let image = UIImage(data: data) else { return nil }
        guard generation == started else { return nil }
        files.store(data, for: url)
        shown = (url, image)
        return image
    }

    func store(_ jpeg: Data, for url: URL) {
        files.store(jpeg, for: url)
        shown = UIImage(data: jpeg).map { (url, $0) }
    }

    func removeAll() {
        files.removeAll()
        shown = nil
        keptURL = nil
        generation += 1
    }

    func keepOnly(_ url: URL) {
        files.keepOnly(url)
        if let shown, shown.url != url { self.shown = nil }
        // The first known photo starts nothing over; a different one means another account or another photo.
        if let keptURL, keptURL != url { generation += 1 }
        keptURL = url
    }
}
