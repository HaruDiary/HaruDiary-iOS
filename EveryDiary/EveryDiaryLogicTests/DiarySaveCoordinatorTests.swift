import Foundation
import XCTest

@MainActor
final class DiarySaveCoordinatorTests: XCTestCase {
    private func entry() -> DiaryEntry {
        DiaryEntry(title: "산책", content: "오늘의 기록",
                   date: Date(timeIntervalSince1970: 0), emotion: "Good", weather: "u_sun")
    }

    private func image(_ value: UInt8) -> DiaryImageUpload {
        DiaryImageUpload(data: Data([value]), assetIdentifier: "asset-\(value)",
                         captureTime: "2026-09-27", location: "Seoul")
    }

    func testCreateWithoutImagesStillWritesOneDiary() {
        let auth = SaveTestAuthentication()
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        var results: [Result<Void, Error>] = []

        coordinator.create(entry(), images: []) { results.append($0) }

        XCTAssertEqual(writer.created.count, 1)
        XCTAssertEqual(writer.created.first?.entry.imageURL, [])
        XCTAssertEqual(writer.created.first?.userID, "user-a")
        XCTAssertEqual(results.count, 1)
        if case .success? = results.first {} else { XCTFail("Create should succeed") }
    }

    func testCreateKeepsInputPhotoOrderWhenUploadsFinishOutOfOrder() async {
        let auth = SaveTestAuthentication()
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        let finished = expectation(description: "Created after both uploads")

        coordinator.create(entry(), images: [image(1), image(2)]) { result in
            if case .failure(let error) = result { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        XCTAssertEqual(storage.uploads.map(\.userID), ["user-a", "user-a"])
        XCTAssertEqual(storage.uploads.map(\.image.assetIdentifier), ["asset-1", "asset-2"])
        XCTAssertTrue(writer.created.isEmpty)

        storage.completeUpload(at: 1, url: "second")
        XCTAssertTrue(writer.created.isEmpty)
        storage.completeUpload(at: 0, url: "first")
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(writer.created.first?.entry.imageURL, ["first", "second"])
    }

    func testCreateReportsAuthenticationFailureWithoutWriting() {
        let auth = SaveTestAuthentication()
        auth.result = .failure(SaveTestError.failed)
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        var results: [Result<Void, Error>] = []

        coordinator.create(entry(), images: [image(1)]) { results.append($0) }

        XCTAssertEqual(results.count, 1)
        if case .failure? = results.first {} else { XCTFail("Authentication must fail") }
        XCTAssertTrue(storage.uploads.isEmpty)
        XCTAssertTrue(writer.created.isEmpty)
    }

    func testUpdateClearsImageURLsBeforeDeletingOldPhotosWhenNoNewPhotos() async {
        let auth = SaveTestAuthentication()
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        var updated = entry()
        updated.id = "diary-1"
        updated.imageURL = ["old-1", "old-2"]
        updated.userID = "user-a"
        updated.weatherDescription = "맑음"
        updated.isDeleted = true
        let finished = expectation(description: "Updated before old photos are deleted")

        coordinator.update(updated, diaryID: "diary-1", expectedUserID: "user-a",
                           existingImageURLs: ["old-1", "old-2"],
                           images: []) { result in
            if case .failure(let error) = result { XCTFail("Unexpected error: \(error)") }
            finished.fulfill()
        }
        XCTAssertNil(writer.updated.first?.entry.imageURL)
        XCTAssertEqual(storage.deletions.map(\.url), ["old-1", "old-2"])

        storage.completeDeletion(at: 1)
        storage.completeDeletion(at: 0)
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(writer.updated.first?.entry.id, "diary-1")
        XCTAssertEqual(writer.updated.first?.diaryID, "diary-1")
        XCTAssertNil(writer.updated.first?.entry.imageURL)
        XCTAssertEqual(writer.updated.first?.entry.userID, "user-a")
        XCTAssertEqual(writer.updated.first?.entry.weatherDescription, "맑음")
        XCTAssertEqual(writer.updated.first?.entry.isDeleted, true)
        XCTAssertEqual(writer.updated.first?.userID, "user-a")
    }

    func testUpdateDoesNotReplacePhotosWhenAnUploadFails() async {
        let auth = SaveTestAuthentication()
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        let finished = expectation(description: "Upload failure delivered")

        coordinator.update(entry(), diaryID: "diary-1", expectedUserID: "user-a",
                           existingImageURLs: ["old"],
                           images: [image(1), image(2)]) { result in
            if case .failure(let error) = result {
                XCTAssertEqual(error as? DiarySaveError, .photoUploadFailed(1))
            } else {
                XCTFail("A failed photo must not be saved over the existing diary")
            }
            finished.fulfill()
        }
        storage.completeUpload(at: 0, url: nil)
        storage.completeUpload(at: 1, url: "second")
        storage.completeDeletion(at: 0)
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertTrue(writer.updated.isEmpty)
        XCTAssertEqual(storage.deletions.map(\.url), ["second"])
    }

    func testSignedOutUpdateNeverDeletesPhotos() {
        let auth = SaveTestAuthentication()
        auth.currentUserID = nil
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        var results: [Result<Void, Error>] = []

        coordinator.update(entry(), diaryID: "diary-1", expectedUserID: "user-a",
                           existingImageURLs: ["old"],
                           images: [image(1)]) { results.append($0) }

        XCTAssertEqual(results.count, 1)
        if case .failure(let error)? = results.first {
            XCTAssertTrue(error is DiarySaveError)
        } else {
            XCTFail("Missing user must fail before deleting images")
        }
        XCTAssertTrue(storage.deletions.isEmpty)
        XCTAssertTrue(storage.uploads.isEmpty)
        XCTAssertTrue(writer.updated.isEmpty)
    }

    func testChangedAccountCannotDeleteOrRewriteOldDiary() {
        let auth = SaveTestAuthentication()
        auth.currentUserID = "user-b"
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        var result: Result<Void, Error>?

        coordinator.update(entry(), diaryID: "diary-1", expectedUserID: "user-a",
                           existingImageURLs: ["old"], images: [image(1)]) { result = $0 }

        if case .failure(let error)? = result {
            XCTAssertTrue(error is DiarySaveError)
        } else {
            XCTFail("Account switch must reject the save")
        }
        XCTAssertTrue(storage.deletions.isEmpty)
        XCTAssertTrue(storage.uploads.isEmpty)
        XCTAssertTrue(writer.updated.isEmpty)
    }
}

private enum SaveTestError: Error {
    case failed
}

@MainActor
final class UnusedDiarySaving: DiarySaving {
    var currentUserID: String? { "test-user" }
    func create(_ entry: DiaryEntry, images uploads: [DiaryImageUpload],
                completion: @escaping (Result<Void, Error>) -> Void) {
        XCTFail("Composition must not save a diary")
    }

    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                existingImageURLs: [String],
                images uploads: [DiaryImageUpload],
                completion: @escaping (Result<Void, Error>) -> Void) {
        XCTFail("Composition must not update a diary")
    }
}

@MainActor
private final class SaveTestAuthentication: DiarySaveAuthenticating {
    var currentUserID: String? = "user-a"
    var result: Result<String, Error> = .success("user-a")

    func authenticateIfNeeded(completion: @escaping (Result<String, Error>) -> Void) {
        completion(result)
    }
}

@MainActor
private final class SaveTestImages: DiaryImageStoring {
    struct Upload {
        let image: DiaryImageUpload
        let userID: String
        let completion: (String?) -> Void
    }
    struct Deletion {
        let url: String
        let completion: () -> Void
    }

    private(set) var uploads: [Upload] = []
    private(set) var deletions: [Deletion] = []

    func upload(_ image: DiaryImageUpload, userID: String, completion: @escaping (String?) -> Void) {
        uploads.append(Upload(image: image, userID: userID, completion: completion))
    }

    func delete(url: String, completion: @escaping () -> Void) {
        deletions.append(Deletion(url: url, completion: completion))
    }

    func completeUpload(at index: Int, url: String?) {
        uploads[index].completion(url)
    }

    func completeDeletion(at index: Int) {
        deletions[index].completion()
    }
}

@MainActor
private final class SaveTestWriter: DiaryEntryWriting {
    struct Write {
        let entry: DiaryEntry
        let userID: String
        let diaryID: String?
    }
    private(set) var created: [Write] = []
    private(set) var updated: [Write] = []
    var error: Error?

    func create(_ entry: DiaryEntry, userID: String, completion: @escaping (Error?) -> Void) {
        created.append(Write(entry: entry, userID: userID, diaryID: nil))
        completion(error)
    }

    func update(_ entry: DiaryEntry, diaryID: String, userID: String,
                completion: @escaping (Error?) -> Void) {
        updated.append(Write(entry: entry, userID: userID, diaryID: diaryID))
        completion(error)
    }
}
