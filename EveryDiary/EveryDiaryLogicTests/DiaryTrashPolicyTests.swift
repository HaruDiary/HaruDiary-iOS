import Foundation
import XCTest

final class DiaryTrashPolicyTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let effective = DiaryTrashPolicy.effectiveDate

    private func calendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        return calendar
    }

    private func trashed(at deleteDate: Date?) -> DiaryEntry {
        var entry = DiaryEntry(title: "휴지통", content: "", date: Date(timeIntervalSince1970: 0), emotion: "", weather: "")
        entry.isDeleted = true
        entry.deleteDate = deleteDate
        return entry
    }

    func testDiaryTrashedAfterPolicyStartExpiresThirtyDaysLater() throws {
        let deletedAt = effective.addingTimeInterval(5 * day)
        let entry = trashed(at: deletedAt)

        XCTAssertEqual(DiaryTrashPolicy.deadline(for: entry, calendar: try calendar()), deletedAt.addingTimeInterval(30 * day))
        XCTAssertFalse(DiaryTrashPolicy.isExpired(entry, now: deletedAt.addingTimeInterval(30 * day - 1), calendar: try calendar()))
        XCTAssertTrue(DiaryTrashPolicy.isExpired(entry, now: deletedAt.addingTimeInterval(30 * day), calendar: try calendar()))
    }

    func testDiaryTrashedLongBeforePolicyStartIsNotDeletedOnFirstLaunch() throws {
        let entry = trashed(at: effective.addingTimeInterval(-400 * day))

        XCTAssertFalse(DiaryTrashPolicy.isExpired(entry, now: effective.addingTimeInterval(day), calendar: try calendar()))
        XCTAssertEqual(DiaryTrashPolicy.deadline(for: entry, calendar: try calendar()), effective.addingTimeInterval(30 * day))
    }

    func testTrashedDiaryWithoutDeleteDateCountsFromPolicyStart() throws {
        let entry = trashed(at: nil)

        XCTAssertEqual(DiaryTrashPolicy.deadline(for: entry, calendar: try calendar()), effective.addingTimeInterval(30 * day))
    }

    func testDaysRemainingRoundsUpAndReachesZeroAtDeadline() throws {
        let deletedAt = effective.addingTimeInterval(day)
        let entry = trashed(at: deletedAt)
        let calendar = try calendar()

        XCTAssertEqual(DiaryTrashPolicy.daysRemaining(for: entry, now: deletedAt, calendar: calendar), 30)
        XCTAssertEqual(DiaryTrashPolicy.daysRemaining(for: entry, now: deletedAt.addingTimeInterval(29 * day + 3600), calendar: calendar), 1)
        XCTAssertEqual(DiaryTrashPolicy.daysRemaining(for: entry, now: deletedAt.addingTimeInterval(30 * day), calendar: calendar), 0)
    }

    func testActiveDiaryHasNoDeadline() throws {
        var entry = trashed(at: effective)
        entry.isDeleted = false

        XCTAssertNil(DiaryTrashPolicy.deadline(for: entry, calendar: try calendar()))
        XCTAssertNil(DiaryTrashPolicy.daysRemaining(for: entry, now: effective, calendar: try calendar()))
        XCTAssertFalse(DiaryTrashPolicy.isExpired(entry, now: effective.addingTimeInterval(1000 * day), calendar: try calendar()))
    }
}
