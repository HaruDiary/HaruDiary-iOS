import UIKit
import XCTest

@MainActor
final class ProfilePhotoFilesTests: XCTestCase {
    private var directory: URL!
    private let first = URL(string: "https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/uid123%2Fprofile-A1.jpg?alt=media&token=t")!
    private let second = URL(string: "https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/uid123%2Fprofile-B2.jpg?alt=media&token=t")!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("profile-photo-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testStoredPhotoIsReadBackByAnotherInstance() {
        let files = ProfilePhotoFiles(directory: directory)
        XCTAssertNil(files.data(for: first))

        files.store(Data([1, 2, 3]), for: first)

        // A new instance is what the app has after it was closed and opened again.
        XCTAssertEqual(ProfilePhotoFiles(directory: directory).data(for: first), Data([1, 2, 3]))
    }

    func testOnlyTheLatestPhotoIsKept() throws {
        let files = ProfilePhotoFiles(directory: directory)
        files.store(Data([1]), for: first)
        files.store(Data([2]), for: second)

        XCTAssertNil(files.data(for: first))
        XCTAssertEqual(files.data(for: second), Data([2]))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 1)
    }

    func testTheSamePhotoWithANewTokenIsTheSameFile() {
        let files = ProfilePhotoFiles(directory: directory)
        files.store(Data([1]), for: first)
        let renewed = URL(string: "https://firebasestorage.googleapis.com/v0/b/app.appspot.com/o/uid123%2Fprofile-A1.jpg?alt=media&token=other")!

        XCTAssertEqual(files.data(for: renewed), Data([1]))
    }

    func testRemoveAllLeavesNothing() {
        let files = ProfilePhotoFiles(directory: directory)
        files.store(Data([1]), for: first)

        files.removeAll()

        XCTAssertNil(files.data(for: first))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testLoaderGivesAStoredPhotoWithoutDownloading() async throws {
        let jpeg = try XCTUnwrap(Self.jpeg())
        var downloads = 0
        let loader = ProfilePhotoLoader(files: ProfilePhotoFiles(directory: directory)) { _ in
            downloads += 1
            return jpeg
        }
        XCTAssertNil(loader.image(for: first))

        // The first time it is downloaded and kept.
        let loaded = await loader.load(first)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(downloads, 1)

        // After a restart it comes from the device at once.
        let restarted = ProfilePhotoLoader(files: ProfilePhotoFiles(directory: directory)) { _ in
            downloads += 1
            return jpeg
        }
        XCTAssertNotNil(restarted.image(for: first))
        XCTAssertEqual(downloads, 1)
    }

    func testLoaderShowsAnUploadedPhotoAtOnceAndForgetsItWhenRemoved() throws {
        let jpeg = try XCTUnwrap(Self.jpeg())
        let loader = ProfilePhotoLoader(files: ProfilePhotoFiles(directory: directory)) { _ in throw URLError(.notConnectedToInternet) }

        loader.store(jpeg, for: first)
        XCTAssertNotNil(loader.image(for: first))
        XCTAssertNil(loader.image(for: second))

        loader.removeAll()
        XCTAssertNil(loader.image(for: first))
    }

    private static func jpeg() -> Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }.jpegData(compressionQuality: 0.8)
    }
}
