import Foundation

struct DiaryImageUpload {
    let data: Data
    let assetIdentifier: String
    let captureTime: String?
    let location: String?
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
    case photoUploadFailed(Int)
}

@MainActor
protocol DiarySaving {
    var currentUserID: String? { get }
    func create(_ entry: DiaryEntry, images uploads: [DiaryImageUpload],
                completion: @escaping (Result<Void, Error>) -> Void)
    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                existingImageURLs: [String],
                images uploads: [DiaryImageUpload],
                completion: @escaping (Result<Void, Error>) -> Void)
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
                completion: @escaping (Result<Void, Error>) -> Void) {
        authentication.authenticateIfNeeded { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let userID):
                self.upload(uploads, userID: userID) { urls in
                    var entry = entry
                    entry.imageURL = urls
                    self.entries.create(entry, userID: userID) { error in
                        completion(error.map(Result.failure) ?? .success(()))
                    }
                }
            }
        }
    }

    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                existingImageURLs: [String],
                images uploads: [DiaryImageUpload],
                completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userID = authentication.currentUserID else {
            completion(.failure(DiarySaveError.signedOut))
            return
        }
        guard userID == expectedUserID else {
            completion(.failure(DiarySaveError.accountChanged))
            return
        }
        upload(uploads, userID: userID) { urls in
            let failedCount = uploads.count - urls.count
            guard failedCount == 0 else {
                self.delete(urls) {
                    completion(.failure(DiarySaveError.photoUploadFailed(failedCount)))
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
                self.delete(replaced) { completion(.success(())) }
            }
        }
    }

    private func upload(_ uploads: [DiaryImageUpload], userID: String,
                        completion: @escaping ([String]) -> Void) {
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
            completion(urls.compactMap { $0 })
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
