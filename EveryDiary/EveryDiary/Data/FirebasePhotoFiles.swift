import FirebaseStorage
import Foundation

/// Stored diary photos, addressed by the download URLs saved in `imageURL`.
enum FirebasePhotoFiles {
    /// Returns true when the photo is gone, including one an earlier, partly failed attempt already removed.
    @MainActor
    static func delete(urlString: String) async -> Bool {
        let error = await withCheckedContinuation { (continuation: CheckedContinuation<Error?, Never>) in
            FirebaseStorageManager.deleteImage(urlString: urlString) { continuation.resume(returning: $0) }
        }
        return error.map(isMissingObject) ?? true
    }

    static func isMissingObject(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == StorageErrorDomain && error.code == StorageErrorCode.objectNotFound.rawValue
    }
}
