import FirebaseAuth
import Foundation

@MainActor
final class LiveDiarySaveAuthentication: DiarySaveAuthenticating {
    var currentUserID: String? { Auth.auth().currentUser?.uid }

    func authenticateIfNeeded(completion: @escaping (Result<String, Error>) -> Void) {
        DiaryManager.shared.authenticateAnonymouslyIfNeeded { error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                } else if let userID = Auth.auth().currentUser?.uid {
                    completion(.success(userID))
                } else {
                    completion(.failure(DiarySaveError.signedOut))
                }
            }
        }
    }
}

@MainActor
final class LiveDiaryImageStore: DiaryImageStoring {
    func upload(_ image: DiaryImageUpload, userID: String, completion: @escaping (String?) -> Void) {
        FirebaseStorageManager.uploadImage(data: image.data, pathRoot: userID,
                                           assetIdentifier: image.assetIdentifier,
                                           captureTime: image.captureTime, location: image.location) { url in
            DispatchQueue.main.async { completion(url?.absoluteString) }
        }
    }

    func delete(url: String, completion: @escaping () -> Void) {
        FirebaseStorageManager.deleteImage(urlString: url) { _ in
            DispatchQueue.main.async { completion() }
        }
    }
}

@MainActor
final class LiveDiaryEntryWriter: DiaryEntryWriting {
    func create(_ entry: DiaryEntry, userID: String, completion: @escaping (Error?) -> Void) {
        DiaryManager.shared.addDiary(diary: entry, userID: userID) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    func update(_ entry: DiaryEntry, diaryID: String, userID: String,
                completion: @escaping (Error?) -> Void) {
        DiaryManager.shared.updateDiary(diaryID: diaryID, newDiary: entry, userID: userID) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
}
