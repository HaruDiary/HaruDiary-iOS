//
//  DiaryUploadManager.swift
//  EveryDiary
//
//  Created by t2023-m0026 on 3/26/24.
//

import UIKit

import FirebaseAuth

//MARK: 일기, 이미지 데이터의 업로드 & 업데이트 프로세스 관리
// DiaryManager(DiaryEntry CRUD)와 FirebaseStorageManager(Image Upload, Delete, Download, URL제공)를 사용해 일기데이터를 생성, 업데이트하는 역할
class DiaryUploadManager {
    static let shared = DiaryUploadManager()
    private var retentionList = [UIViewController]()
    
    func retain(_ vc: UIViewController) {
        retentionList.append(vc)
    }
    func release(_ vc: UIViewController) {
        retentionList = retentionList.filter { $0 !== vc }
    }
    
    func uploadDairy(diaryEntry: DiaryEntry, imagesLocationInfo: [ImageLocationInfo], completion: @escaping (Bool) -> Void) {
        // 이미지 업로드 후 URL 배열 반환
        uploadImages(imagesLocationInfo) { imageURLs in
            guard !imageURLs.isEmpty else {
                completion(false)
                return
            }
            // 이미지 URL을 포함한 일기 엔트리의 생성 및 업로드
            var newDiaryEntry = diaryEntry
            newDiaryEntry.imageURL = imageURLs
            DiaryManager.shared.addDiary(diary: newDiaryEntry) { error in
                if let error = error {
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    enum UpdateResult {
        case saved
        /// The text changes were saved with the diary's previous photos because a photo upload failed.
        case savedWithoutPhotoChanges(failedCount: Int)
        case failed
    }

    func updateDiary(diaryID: String, diaryEntry: DiaryEntry, imagesLocationInfo: [ImageLocationInfo], existingImageURLs: [String], completion: @escaping (UpdateResult) -> Void) {
        Task { @MainActor in
            // Upload → save → delete old files, so a failure never removes the photos the diary already has.
            let outcome = await DiaryPhotoReplacement.replace(
                previousURLs: existingImageURLs,
                upload: { await self.uploadEach(imagesLocationInfo) },
                save: { urls in
                    var entry = diaryEntry
                    entry.imageURL = urls.isEmpty ? nil : urls
                    return await self.save(diaryID: diaryID, entry: entry)
                },
                delete: { urls in await self.deleteImages(urls) }
            )
            switch outcome {
            case .updated:
                completion(.saved)
            case .saveFailed:
                completion(.failed)
            case .uploadFailed(let failedCount):
                var entry = diaryEntry
                entry.imageURL = existingImageURLs.isEmpty ? nil : existingImageURLs
                let saved = await self.save(diaryID: diaryID, entry: entry)
                completion(saved ? .savedWithoutPhotoChanges(failedCount: failedCount) : .failed)
            }
        }
    }

    // One result per photo in order; nil marks a photo that could not be uploaded.
    @MainActor
    private func uploadEach(_ imagesLocationInfo: [ImageLocationInfo]) async -> [String?] {
        var results: [String?] = []
        for info in imagesLocationInfo {
            guard let assetIdentifier = info.assetIdentifier else { continue }
            let url = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                FirebaseStorageManager.uploadImage(
                    image: [info.image],
                    pathRoot: Auth.auth().currentUser?.uid ?? "UnknownUser",
                    assetIdentifier: assetIdentifier,
                    captureTime: info.captureTime,
                    location: info.location
                ) { urls in
                    continuation.resume(returning: urls?.first?.absoluteString)
                }
            }
            results.append(url)
        }
        return results
    }

    @MainActor
    private func save(diaryID: String, entry: DiaryEntry) async -> Bool {
        await withCheckedContinuation { continuation in
            DiaryManager.shared.updateDiary(diaryID: diaryID, newDiary: entry) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    @MainActor
    private func deleteImages(_ urls: [String]) async {
        guard !urls.isEmpty else { return }
        var failedCount = 0
        for url in urls {
            let failed = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                FirebaseStorageManager.deleteImage(urlString: url) { error in continuation.resume(returning: error != nil) }
            }
            if failed { failedCount += 1 }
        }
        // Counts only; a failed delete leaves an unused file in Storage but never affects the diary.
        print("Removed \(urls.count - failedCount) photo file(s), \(failedCount) failed")
    }

    private func uploadImages(_ imagesLocationInfo: [ImageLocationInfo], completion: @escaping ([String]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var uploadedImageURLs = Array(repeating: String?.none, count: imagesLocationInfo.count) // URL 배열을 nil로 초기화
        
        // 이미지와 메타데이터 업로드
        print("before enter")
        for (index ,imageLocationInfo) in imagesLocationInfo.enumerated() {
            guard let assetIdentifier = imageLocationInfo.assetIdentifier else { continue }
            
            dispatchGroup.enter()
            print("dispatchGroup entered")
            // 촬영 시간과 위치 정보를 포함하여 업로드
            FirebaseStorageManager.uploadImage(
                image: [imageLocationInfo.image],
                pathRoot: Auth.auth().currentUser?.uid ?? "UnknownUser",
                assetIdentifier: assetIdentifier,
                captureTime: imageLocationInfo.captureTime,
                location: imageLocationInfo.location
            ) { urls in
                defer { dispatchGroup.leave() }
                print("Image Uploaded")
                if let url = urls?.first?.absoluteString {
                    uploadedImageURLs[index] = url              // 원본 배열의 순서에 따라 URL 저장
                    return
                }
            }
        }
        dispatchGroup.notify(queue: .main) {
            print("dispatchGroup notify")
            let orderedUploadImageURLs = uploadedImageURLs.compactMap { $0 }     // nil 값을 제거하고 URL 순서대로 정렬
            print("completion 콜백 호출 전: \(orderedUploadImageURLs)")
            completion(orderedUploadImageURLs)     // 순서대로 정렬된 URL 배열로 완료 콜백 호출
        }
    }
}
