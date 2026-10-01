import Foundation

/// The profile photo as a file in the caches folder, named after the photo's Storage path.
/// The folder can be emptied by the system; the photo is then downloaded again.
@MainActor
final class ProfilePhotoFiles: ProfilePhotoStoring {
    private let directory: URL
    private let files: FileManager

    init(directory: URL, files: FileManager = .default) {
        self.directory = directory
        self.files = files
    }

    static func inCaches() -> ProfilePhotoFiles {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return ProfilePhotoFiles(directory: caches.appendingPathComponent("ProfilePhoto", isDirectory: true))
    }

    func data(for url: URL) -> Data? {
        try? Data(contentsOf: file(for: url))
    }

    func store(_ jpeg: Data, for url: URL) {
        removeAll()
        do {
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
            try jpeg.write(to: file(for: url), options: .atomic)
        } catch {
            // Without the file the photo is downloaded the next time it is shown.
            let error = error as NSError
            print("Profile photo not kept: \(error.domain) \(error.code)")
        }
    }

    func removeAll() {
        try? files.removeItem(at: directory)
    }

    /// Each upload has its own Storage path (`uid/profile-….jpg`), so a changed photo never reads the old file.
    private func file(for url: URL) -> URL {
        let name = ProfilePicture.storagePath(of: url) ?? url.absoluteString
        let safe = String(name.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." ? $0 : "_" })
        return directory.appendingPathComponent(safe)
    }
}
