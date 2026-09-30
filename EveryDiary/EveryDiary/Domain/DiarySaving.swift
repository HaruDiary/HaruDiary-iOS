import Foundation

struct DiaryImageUpload {
    let data: Data
    let assetIdentifier: String
    let captureTime: String?
    let location: String?
}

/// A photo of an edited diary, in the order the diary shows it.
enum DiaryPhotoSlot {
    /// Already stored: its file and URL are kept as they are, with no second upload.
    case stored(url: String)
    case new(DiaryImageUpload)
}

@MainActor
protocol DiarySaveAuthenticating {
    var currentUserID: String? { get }
    func authenticateIfNeeded(completion: @escaping (Result<String, Error>) -> Void)
}

@MainActor
protocol DiaryImageStoring {
    func upload(_ image: DiaryImageUpload, userID: String, completion: @escaping (String?) -> Void)
    func delete(url: String, completion: @escaping () -> Void)
}

@MainActor
protocol DiaryEntryWriting {
    func create(_ entry: DiaryEntry, userID: String, completion: @escaping (Error?) -> Void)
    func update(_ entry: DiaryEntry, diaryID: String, userID: String, completion: @escaping (Error?) -> Void)
}

enum DiarySaveError: Error, Equatable {
    case signedOut
    case accountChanged
}

enum DiarySaveOutcome: Equatable {
    case saved
    case savedWithMissingPhotos(Int)
    /// Only the text was saved; the stored photos were not all loaded, so they were left as they were.
    case savedKeepingPhotos
}

/// Loading an edited diary's stored photos. Photos may be replaced only when every one of them arrived:
/// a photo still loading or that failed to load is not in the editor, and replacing would delete it.
struct ExistingPhotoLoad: Equatable {
    let expected: Int
    private(set) var loaded = 0
    private(set) var failed = 0

    init(expected: Int) {
        self.expected = expected
    }

    /// Every photo either arrived or failed, so the editor can stop showing its loading cell.
    var isSettled: Bool { loaded + failed >= expected }
    var allLoaded: Bool { failed == 0 && loaded >= expected }

    mutating func photoArrived() {
        loaded += 1
    }

    mutating func photoFailed() {
        failed += 1
    }
}

@MainActor
protocol DiarySaving {
    var currentUserID: String? { get }
    func create(_ entry: DiaryEntry, images uploads: [DiaryImageUpload],
                unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void)
    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                existingImageURLs: [String],
                images uploads: [DiaryImageUpload],
                unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void)
    /// Saves `photos` in order: stored ones keep their URL, new ones are uploaded, and stored files no longer
    /// in the list are deleted after the diary is saved. If a new photo cannot be uploaded (or `unreadablePhotoCount`
    /// is not 0), the new uploads are removed and the diary keeps `existingImageURLs`, with the text saved.
    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                existingImageURLs: [String],
                photos: [DiaryPhotoSlot],
                unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void)
    /// Saves the text and keeps `existingImageURLs` as they are, without uploading or deleting any photo.
    func updateKeepingPhotos(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                             existingImageURLs: [String],
                             completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void)
}

@MainActor
final class DiarySaveCoordinator: DiarySaving {
    private let authentication: any DiarySaveAuthenticating
    private let images: any DiaryImageStoring
    private let entries: any DiaryEntryWriting
    var currentUserID: String? { authentication.currentUserID }

    init(authentication: any DiarySaveAuthenticating, images: any DiaryImageStoring,
         entries: any DiaryEntryWriting) {
        self.authentication = authentication
        self.images = images
        self.entries = entries
    }

    func create(_ entry: DiaryEntry, images uploads: [DiaryImageUpload],
                unreadablePhotoCount: Int = 0,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        authentication.authenticateIfNeeded { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let userID):
                self.upload(uploads, userID: userID) { urls in
                    let missing = unreadablePhotoCount + uploads.count - urls.count
                    var entry = entry
                    entry.imageURL = urls
                    self.entries.create(entry, userID: userID) { error in
                        if let error {
                            self.delete(urls) { completion(.failure(error)) }
                            return
                        }
                        completion(.success(missing > 0 ? .savedWithMissingPhotos(missing) : .saved))
                    }
                }
            }
        }
    }

    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                existingImageURLs: [String],
                images uploads: [DiaryImageUpload],
                unreadablePhotoCount: Int = 0,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        guard let userID = authentication.currentUserID else {
            completion(.failure(DiarySaveError.signedOut))
            return
        }
        guard userID == expectedUserID else {
            completion(.failure(DiarySaveError.accountChanged))
            return
        }
        upload(uploads, userID: userID) { urls in
            let missing = unreadablePhotoCount + uploads.count - urls.count
            if missing > 0 {
                self.delete(urls) {
                    var kept = entry
                    kept.imageURL = existingImageURLs.isEmpty ? nil : existingImageURLs
                    self.entries.update(kept, diaryID: diaryID, userID: userID) { error in
                        if let error {
                            completion(.failure(error))
                            return
                        }
                        completion(.success(.savedWithMissingPhotos(missing)))
                    }
                }
                return
            }
            var entry = entry
            entry.imageURL = urls.isEmpty ? nil : urls
            self.entries.update(entry, diaryID: diaryID, userID: userID) { error in
                if let error {
                    self.delete(urls) { completion(.failure(error)) }
                    return
                }
                let replaced = existingImageURLs.filter { !urls.contains($0) }
                self.delete(replaced) { completion(.success(.saved)) }
            }
        }
    }

    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                existingImageURLs: [String],
                photos: [DiaryPhotoSlot],
                unreadablePhotoCount: Int = 0,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        guard let userID = authentication.currentUserID else {
            completion(.failure(DiarySaveError.signedOut))
            return
        }
        guard userID == expectedUserID else {
            completion(.failure(DiarySaveError.accountChanged))
            return
        }
        let uploads = photos.compactMap { slot -> DiaryImageUpload? in
            if case .new(let upload) = slot { return upload }
            return nil
        }
        uploadKeepingPositions(uploads, userID: userID) { results in
            let uploaded = results.compactMap { $0 }
            let missing = unreadablePhotoCount + results.count - uploaded.count
            if missing > 0 {
                self.delete(uploaded) {
                    var kept = entry
                    kept.imageURL = existingImageURLs.isEmpty ? nil : existingImageURLs
                    self.entries.update(kept, diaryID: diaryID, userID: userID) { error in
                        if let error {
                            completion(.failure(error))
                            return
                        }
                        completion(.success(.savedWithMissingPhotos(missing)))
                    }
                }
                return
            }
            var next = uploaded.makeIterator()
            let urls = photos.compactMap { slot -> String? in
                switch slot {
                case .stored(let url): return url
                case .new: return next.next()
                }
            }
            var entry = entry
            entry.imageURL = urls.isEmpty ? nil : urls
            self.entries.update(entry, diaryID: diaryID, userID: userID) { error in
                if let error {
                    self.delete(uploaded) { completion(.failure(error)) }
                    return
                }
                let removed = existingImageURLs.filter { !urls.contains($0) }
                self.delete(removed) { completion(.success(.saved)) }
            }
        }
    }

    func updateKeepingPhotos(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                             existingImageURLs: [String],
                             completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        guard let userID = authentication.currentUserID else {
            completion(.failure(DiarySaveError.signedOut))
            return
        }
        guard userID == expectedUserID else {
            completion(.failure(DiarySaveError.accountChanged))
            return
        }
        var kept = entry
        kept.imageURL = existingImageURLs.isEmpty ? nil : existingImageURLs
        entries.update(kept, diaryID: diaryID, userID: userID) { error in
            if let error {
                completion(.failure(error))
                return
            }
            completion(.success(.savedKeepingPhotos))
        }
    }

    private func upload(_ uploads: [DiaryImageUpload], userID: String,
                        completion: @escaping ([String]) -> Void) {
        uploadKeepingPositions(uploads, userID: userID) { completion($0.compactMap { $0 }) }
    }

    /// One result per upload, in input order; nil where the upload failed.
    private func uploadKeepingPositions(_ uploads: [DiaryImageUpload], userID: String,
                                        completion: @escaping ([String?]) -> Void) {
        guard !uploads.isEmpty else {
            completion([])
            return
        }
        let group = DispatchGroup()
        var urls = Array<String?>(repeating: nil, count: uploads.count)
        for (index, image) in uploads.enumerated() {
            group.enter()
            images.upload(image, userID: userID) { url in
                urls[index] = url
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion(urls)
        }
    }

    private func delete(_ urls: [String], completion: @escaping () -> Void) {
        guard !urls.isEmpty else {
            completion()
            return
        }
        let group = DispatchGroup()
        for url in urls {
            group.enter()
            images.delete(url: url) {
                group.leave()
            }
        }
        group.notify(queue: .main, execute: completion)
    }
}
