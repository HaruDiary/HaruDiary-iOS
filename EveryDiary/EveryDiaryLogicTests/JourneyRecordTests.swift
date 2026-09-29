import Foundation
import XCTest

final class JourneyRecordTests: XCTestCase {
    private func calendar(secondsFromGMT: Int = 9 * 3600) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: secondsFromGMT))
        return calendar
    }

    private func entry(_ dateString: String, isDeleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: "제목", content: "테스트 본문", date: Date(timeIntervalSince1970: 0), emotion: "Grinning face", weather: "u_sun")
        entry.dateString = dateString
        entry.isDeleted = isDeleted
        return entry
    }

    func testSeveralDiariesOnOneDayLightOneWindow() throws {
        let calendar = try calendar()
        let record = JourneyRecord(entries: [
            entry("2026-09-15 09:00:00 +0900"),
            entry("2026-09-15 21:00:00 +0900"),
            entry("2026-09-16 08:00:00 +0900")
        ], calendar: calendar)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 20)))
        XCTAssertEqual(record.month(containing: today, calendar: calendar).days, [15, 16])
    }

    func testTrashedAndUnreadableDiariesLightNoWindow() throws {
        let calendar = try calendar()
        let record = JourneyRecord(entries: [
            entry("2026-09-15 09:00:00 +0900", isDeleted: true),
            entry("not a date")
        ], calendar: calendar)
        XCTAssertTrue(record.months.isEmpty)
    }

    func testFirstDayOfNextMonthBelongsToThatMonth() throws {
        // The previous query also returned the 1st of the next month and counted it in the current month.
        let calendar = try calendar()
        let record = JourneyRecord(entries: [
            entry("2026-09-30 23:59:59 +0900"),
            entry("2026-10-01 00:00:00 +0900")
        ], calendar: calendar)
        XCTAssertEqual(record.months.map(\.title), ["2026.10", "2026.09"])
        XCTAssertEqual(record.months.map(\.days), [[1], [30]])
    }

    func testMonthsUseTheCalendarTimeZone() throws {
        let entries = [entry("2026-09-30 20:00:00 +0000")]
        XCTAssertEqual(JourneyRecord(entries: entries, calendar: try calendar(secondsFromGMT: 9 * 3600)).months.first?.title, "2026.10")
        XCTAssertEqual(JourneyRecord(entries: entries, calendar: try calendar(secondsFromGMT: 0)).months.first?.title, "2026.09")
    }

    func testMonthsAreNewestFirstAcrossYears() throws {
        let calendar = try calendar()
        let record = JourneyRecord(entries: [
            entry("2025-12-31 10:00:00 +0900"),
            entry("2026-02-01 10:00:00 +0900"),
            entry("2026-01-10 10:00:00 +0900")
        ], calendar: calendar)
        XCTAssertEqual(record.months.map(\.title), ["2026.02", "2026.01", "2025.12"])
    }

    func testMonthWithoutDiariesHasNoDays() throws {
        let calendar = try calendar()
        let record = JourneyRecord(entries: [entry("2026-08-15 09:00:00 +0900")], calendar: calendar)
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let month = record.month(containing: today, calendar: calendar)
        XCTAssertEqual(month.title, "2026.09")
        XCTAssertTrue(month.days.isEmpty)
    }
}
