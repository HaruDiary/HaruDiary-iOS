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

    func testAnotherAccountsPhotoIsDroppedWhileTheShownOneStays() throws {
        // Two files can only be there when they were written apart; `store` itself keeps one.
        let files = ProfilePhotoFiles(directory: directory)
        files.store(Data([1]), for: first)
        let other = directory.appendingPathComponent("uid999_profile-Z9.jpg")
        try Data([9]).write(to: other)

        files.keepOnly(first)

        XCTAssertEqual(files.data(for: first), Data([1]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: other.path))

        // The account now shows another photo: the kept one is not its photo and goes.
        files.keepOnly(second)
        XCTAssertNil(files.data(for: first))
    }

    func testLoaderForgetsThePreviousAccountsPhotoInMemoryToo() throws {
        let jpeg = try XCTUnwrap(Self.jpeg())
        let loader = ProfilePhotoLoader(files: ProfilePhotoFiles(directory: directory)) { _ in throw URLError(.notConnectedToInternet) }
        loader.store(jpeg, for: first)

        loader.keepOnly(first)
        XCTAssertNotNil(loader.image(for: first), "The shown account's photo stays")

        loader.keepOnly(second)
        XCTAssertNil(loader.image(for: first))
    }

    func testADownloadEndingAfterTheAccountChangedIsNotKept() async throws {
        let jpeg = try XCTUnwrap(Self.jpeg())
        let files = ProfilePhotoFiles(directory: directory)
        var release: CheckedContinuation<Void, Never>?
        let loader = ProfilePhotoLoader(files: files) { _ in
            await withCheckedContinuation { release = $0 }
            return jpeg
        }
        loader.keepOnly(first)

        // A's photo is being downloaded when B signs in.
        async let late = loader.load(first)
        try await waitUntil { release != nil }
        loader.keepOnly(second)
        release?.resume()
        let lateImage = await late

        XCTAssertNil(lateImage)
        XCTAssertNil(files.data(for: first), "A's photo is not written back")
        XCTAssertNil(loader.image(for: first))

        // The same after a sign-out.
        release = nil
        loader.keepOnly(first)
        async let afterSignOut = loader.load(first)
        try await waitUntil { release != nil }
        loader.removeAll()
        release?.resume()
        let signedOutImage = await afterSignOut
        XCTAssertNil(signedOutImage)
        XCTAssertNil(files.data(for: first))
    }

    func testADownloadOfTheShownAccountsPhotoIsKeptAsBefore() async throws {
        let jpeg = try XCTUnwrap(Self.jpeg())
        let files = ProfilePhotoFiles(directory: directory)
        var release: CheckedContinuation<Void, Never>?
        let loader = ProfilePhotoLoader(files: files) { _ in
            await withCheckedContinuation { release = $0 }
            return jpeg
        }

        // The account becomes known while its own photo is downloaded, and is told again later.
        async let loading = loader.load(first)
        try await waitUntil { release != nil }
        loader.keepOnly(first)
        loader.keepOnly(first)
        release?.resume()
        let image = await loading

        XCTAssertNotNil(image)
        XCTAssertNotNil(files.data(for: first))
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<2000 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out", file: file, line: line)
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
