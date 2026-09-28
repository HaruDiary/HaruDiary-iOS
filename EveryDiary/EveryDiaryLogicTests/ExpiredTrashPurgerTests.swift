import Foundation
import XCTest

@MainActor
final class ExpiredTrashPurgerTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private var now: Date { DiaryTrashPolicy.effectiveDate.addingTimeInterval(60 * day) }

    private func entry(_ id: String, deletedDaysAgo: Double?, isDeleted: Bool = true, images: [String]? = nil) -> DiaryEntry {
        var entry = DiaryEntry(title: id, content: "", date: Date(timeIntervalSince1970: 0), emotion: "", weather: "")
        entry.id = id
        entry.isDeleted = isDeleted
        entry.deleteDate = deletedDaysAgo.map { now.addingTimeInterval(-$0 * day) }
        entry.imageURL = images
        return entry
    }

    private func makePurger(trash: PurgeTrash) throws -> ExpiredTrashPurger {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        return ExpiredTrashPurger(trash: trash, calendar: calendar)
    }

    func testOnlyTrashedDiariesPastThirtyDaysArePermanentlyDeleted() async throws {
        let trash = PurgeTrash()
        let purger = try makePurger(trash: trash)

        let result = await purger.purgeExpired(in: [
            entry("expired", deletedDaysAgo: 31, images: ["a.jpg"]),
            entry("recent", deletedDaysAgo: 29),
            entry("active-old", deletedDaysAgo: 100, isDeleted: false),
        ], userID: "user-a", now: now)

        XCTAssertEqual(result, ExpiredTrashPurger.Result(deletedCount: 1, failedCount: 0))
        XCTAssertEqual(trash.deleted.map(\.diaryID), ["expired"])
        XCTAssertEqual(trash.deleted.first?.userID, "user-a")
        XCTAssertEqual(trash.deleted.first?.imageURLs, ["a.jpg"])
    }

    func testFailedDeletionIsCountedAndRetriedNextTime() async throws {
        let trash = PurgeTrash()
        trash.failingIDs = ["expired"]
        let purger = try makePurger(trash: trash)
        let entries = [entry("expired", deletedDaysAgo: 40)]

        let first = await purger.purgeExpired(in: entries, userID: "user-a", now: now)
        trash.failingIDs = []
        let second = await purger.purgeExpired(in: entries, userID: "user-a", now: now)

        XCTAssertEqual(first.failedCount, 1)
        XCTAssertEqual(second.deletedCount, 1)
    }

    func testConcurrentSnapshotsDoNotDeleteTheSameDiaryTwice() async throws {
        let trash = PurgeTrash()
        trash.suspends = true
        let purger = try makePurger(trash: trash)
        let entries = [entry("expired", deletedDaysAgo: 40)]

        async let first = purger.purgeExpired(in: entries, userID: "user-a", now: now)
        for _ in 0..<1000 where trash.deleted.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let second = await purger.purgeExpired(in: entries, userID: "user-a", now: now)
        trash.resumeAll()
        let firstResult = await first

        XCTAssertEqual(second, ExpiredTrashPurger.Result())
        XCTAssertEqual(firstResult.deletedCount, 1)
        XCTAssertEqual(trash.deleted.count, 1)
    }
}

@MainActor
private final class PurgeTrash: DiaryTrashing {
    struct Deletion {
        let diaryID: String
        let userID: String
        let imageURLs: [String]
    }

    var deleted: [Deletion] = []
    var failingIDs: Set<String> = []
    var suspends = false
    private var pending: [CheckedContinuation<Void, Never>] = []

    func moveToTrash(diaryID: String, userID: String, at date: Date) async throws {}
    func restore(diaryID: String, userID: String) async throws {}

    func deletePermanently(diaryID: String, userID: String, imageURLs: [String]) async throws -> PhotoCleanup {
        deleted.append(Deletion(diaryID: diaryID, userID: userID, imageURLs: imageURLs))
        if suspends {
            await withCheckedContinuation { pending.append($0) }
        }
        if failingIDs.contains(diaryID) {
            throw NSError(domain: "PurgeTests", code: 1)
        }
        return PhotoCleanup(deletedCount: imageURLs.count)
    }

    func resumeAll() {
        pending.forEach { $0.resume() }
        pending = []
    }
}
