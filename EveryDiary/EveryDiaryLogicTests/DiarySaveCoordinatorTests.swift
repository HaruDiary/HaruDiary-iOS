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
        var results: [Result<DiarySaveOutcome, Error>] = []

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
        var results: [Result<DiarySaveOutcome, Error>] = []

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

        var updated = entry()
        updated.title = "바꾼 제목"
        coordinator.update(updated, diaryID: "diary-1", expectedUserID: "user-a",
                           existingImageURLs: ["old"],
                           images: [image(1), image(2)]) { result in
            if case .success(.savedWithMissingPhotos(1)) = result {} else {
                XCTFail("Text must be saved and the missing photo reported")
            }
            finished.fulfill()
        }
        storage.completeUpload(at: 0, url: nil)
        storage.completeUpload(at: 1, url: "second")
        let deletionReady = expectation(description: "Partial upload is removed")
        DispatchQueue.main.async {
            XCTAssertEqual(storage.deletions.map(\.url), ["second"])
            storage.completeDeletion(at: 0)
            deletionReady.fulfill()
        }
        await fulfillment(of: [finished, deletionReady], timeout: 3)
        XCTAssertEqual(writer.updated.first?.entry.title, "바꾼 제목")
        XCTAssertEqual(writer.updated.first?.entry.imageURL, ["old"])
    }

    func testCreateReportsMissingPhotosAndStillWritesTheDiary() async {
        let auth = SaveTestAuthentication()
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        let finished = expectation(description: "Partial create saved")

        coordinator.create(entry(), images: [image(1), image(2)], unreadablePhotoCount: 1) { result in
            if case .success(.savedWithMissingPhotos(2)) = result {} else {
                XCTFail("A missing photo must be reported after the diary is saved")
            }
            finished.fulfill()
        }
        storage.completeUpload(at: 0, url: nil)
        storage.completeUpload(at: 1, url: "kept")
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(writer.created.first?.entry.imageURL, ["kept"])
    }

    func testCreateDeletesUploadedPhotosWhenTheDiaryWriteFails() async {
        let auth = SaveTestAuthentication()
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        writer.error = SaveTestError.failed
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        let finished = expectation(description: "Create failure delivered")

        coordinator.create(entry(), images: [image(1)]) { result in
            if case .failure = result {} else { XCTFail("Writer failure must be reported") }
            finished.fulfill()
        }
        storage.completeUpload(at: 0, url: "orphan")
        let deletionReady = expectation(description: "Orphan upload removed")
        DispatchQueue.main.async {
            XCTAssertEqual(storage.deletions.map(\.url), ["orphan"])
            storage.completeDeletion(at: 0)
            deletionReady.fulfill()
        }
        await fulfillment(of: [finished, deletionReady], timeout: 3)
    }

    func testUpdateKeepsExistingPhotosWhenAPhotoCannotBeRead() async {
        let auth = SaveTestAuthentication()
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        let finished = expectation(description: "Unreadable photo reported")
        var updated = entry()
        updated.content = "바꾼 본문"

        coordinator.update(updated, diaryID: "diary-1", expectedUserID: "user-a",
                           existingImageURLs: ["old"], images: [image(1)],
                           unreadablePhotoCount: 1) { result in
            if case .success(.savedWithMissingPhotos(1)) = result {} else {
                XCTFail("An unreadable photo must stop replacement")
            }
            finished.fulfill()
        }
        storage.completeUpload(at: 0, url: "new")
        let deletionReady = expectation(description: "New upload removed")
        DispatchQueue.main.async {
            storage.completeDeletion(at: 0)
            deletionReady.fulfill()
        }
        await fulfillment(of: [finished, deletionReady], timeout: 3)
        XCTAssertEqual(writer.updated.first?.entry.content, "바꾼 본문")
        XCTAssertEqual(writer.updated.first?.entry.imageURL, ["old"])
        XCTAssertEqual(storage.deletions.map(\.url), ["new"])
    }

    // Saved before the photos finished loading (or after one failed to load): the editor holds none or only some
    // of them, so replacing would delete the rest. Only the text is saved and every stored photo stays.
    func testUpdateKeepingPhotosNeverUploadsOrDeletes() {
        let auth = SaveTestAuthentication()
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        var result: Result<DiarySaveOutcome, Error>?
        var edited = entry()
        edited.content = "바꾼 본문"
        edited.imageURL = []

        coordinator.updateKeepingPhotos(edited, diaryID: "diary-1", expectedUserID: "user-a",
                                        existingImageURLs: ["old-1", "old-2"]) { result = $0 }

        if case .success(.savedKeepingPhotos)? = result {} else { XCTFail("Text must be saved") }
        XCTAssertEqual(writer.updated.first?.entry.content, "바꾼 본문")
        XCTAssertEqual(writer.updated.first?.entry.imageURL, ["old-1", "old-2"])
        XCTAssertTrue(storage.uploads.isEmpty)
        XCTAssertTrue(storage.deletions.isEmpty)
    }

    func testUpdateKeepingPhotosChecksTheAccount() {
        let auth = SaveTestAuthentication()
        auth.currentUserID = "user-b"
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: SaveTestImages(), entries: writer)
        var result: Result<DiarySaveOutcome, Error>?

        coordinator.updateKeepingPhotos(entry(), diaryID: "diary-1", expectedUserID: "user-a",
                                        existingImageURLs: ["old"]) { result = $0 }

        if case .failure(let error)? = result {
            XCTAssertEqual(error as? DiarySaveError, .accountChanged)
        } else {
            XCTFail("Account switch must reject the save")
        }
        XCTAssertTrue(writer.updated.isEmpty)
    }

    func testPhotosCanBeReplacedOnlyWhenEveryStoredPhotoArrived() {
        var none = ExistingPhotoLoad(expected: 0)
        XCTAssertTrue(none.isSettled)
        XCTAssertTrue(none.allLoaded)
        none.photoArrived()
        XCTAssertTrue(none.allLoaded)

        var load = ExistingPhotoLoad(expected: 2)
        XCTAssertFalse(load.isSettled)
        XCTAssertFalse(load.allLoaded)
        load.photoArrived()
        XCTAssertFalse(load.isSettled)
        load.photoFailed()
        // Loading ends so the screen stops waiting, but the missing photo must not be treated as removed.
        XCTAssertTrue(load.isSettled)
        XCTAssertFalse(load.allLoaded)

        var complete = ExistingPhotoLoad(expected: 2)
        complete.photoArrived()
        complete.photoArrived()
        XCTAssertTrue(complete.allLoaded)
    }

    func testSignedOutUpdateNeverDeletesPhotos() {
        let auth = SaveTestAuthentication()
        auth.currentUserID = nil
        let storage = SaveTestImages()
        let writer = SaveTestWriter()
        let coordinator = DiarySaveCoordinator(authentication: auth, images: storage, entries: writer)
        var results: [Result<DiarySaveOutcome, Error>] = []

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
        var result: Result<DiarySaveOutcome, Error>?

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
                unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        XCTFail("Composition must not save a diary")
    }

    func update(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                existingImageURLs: [String],
                images uploads: [DiaryImageUpload],
                unreadablePhotoCount: Int,
                completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
        XCTFail("Composition must not update a diary")
    }

    func updateKeepingPhotos(_ entry: DiaryEntry, diaryID: String, expectedUserID: String,
                             existingImageURLs: [String],
                             completion: @escaping (Result<DiarySaveOutcome, Error>) -> Void) {
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
