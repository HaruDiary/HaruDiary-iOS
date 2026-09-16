import Foundation
import XCTest

final class CalendarDiaryIndexTests: XCTestCase {
    private func calendar(secondsFromGMT: Int = 9 * 3600) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: secondsFromGMT))
        return calendar
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }

    private func entry(_ id: String, dateString: String, isDeleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: id, content: "테스트 본문", date: Date(timeIntervalSince1970: 0), emotion: "Grinning face", weather: "u_sun")
        entry.id = id
        entry.dateString = dateString
        entry.isDeleted = isDeleted
        return entry
    }

    func testSameDayContainsEveryDiaryAndEmptyDayContainsNone() throws {
        let calendar = try calendar()
        let now = try date("2026-09-15T12:00:00Z")
        let index = CalendarDiaryIndex(entries: [
            entry("morning", dateString: "2026-09-15 09:00:00 +0900"),
            entry("evening", dateString: "2026-09-15 21:00:00 +0900")
        ], calendar: calendar, now: now)
        let day = CalendarDay(date: now, calendar: calendar)
        XCTAssertEqual(Set(index.entries(on: day).compactMap(\.id)), ["morning", "evening"])
        XCTAssertTrue(index.entries(on: CalendarDay(date: try date("2026-09-16T00:00:00Z"), calendar: calendar)).isEmpty)
    }

    func testDeletedDiaryIsExcludedFromListAndDecorationAfterRefresh() throws {
        let calendar = try calendar()
        let now = try date("2026-09-15T00:00:00Z")
        let day = CalendarDay(date: now, calendar: calendar)
        let index = CalendarDiaryIndex(entries: [entry("deleted", dateString: "2026-09-15 09:00:00 +0900", isDeleted: true)], calendar: calendar, now: now)
        XCTAssertTrue(index.entries(on: day).isEmpty)
        XCTAssertFalse(index.decoratedDays.contains(day))
    }

    func testPreviousYearDiaryIsIncludedInDecorationUpdates() throws {
        let calendar = try calendar()
        let now = try date("2026-09-15T00:00:00Z")
        let oldDay = CalendarDay(date: try date("2025-12-31T00:00:00Z"), calendar: calendar)
        let index = CalendarDiaryIndex(entries: [entry("previous-year", dateString: "2025-12-31 09:00:00 +0900")], calendar: calendar, now: now)
        XCTAssertTrue(index.decoratedDays.contains(oldDay))
    }

    func testRemovingLastDiaryReloadsItsPreviousDecorationDay() throws {
        let calendar = try calendar()
        let now = try date("2026-09-15T00:00:00Z")
        let day = CalendarDay(date: now, calendar: calendar)
        let index = CalendarDiaryIndex(entries: [], calendar: calendar, now: now)
        XCTAssertEqual(index.decorationDaysToReload(previous: [day]), [day])
        XCTAssertTrue(index.decoratedDays.isEmpty)
    }

    func testStoredOffsetUsesInjectedTimeZoneAcrossYearBoundary() throws {
        let now = try date("2026-01-01T00:00:00Z")
        let entries = [entry("boundary", dateString: "2026-01-01 00:30:00 +0900")]
        let korea = try calendar()
        let utc = try calendar(secondsFromGMT: 0)
        let koreanIndex = CalendarDiaryIndex(entries: entries, calendar: korea, now: now)
        let utcIndex = CalendarDiaryIndex(entries: entries, calendar: utc, now: now)
        XCTAssertEqual(koreanIndex.entries(on: CalendarDay(date: now, calendar: korea)).first?.id, "boundary")
        XCTAssertEqual(utcIndex.entries(on: CalendarDay(date: try date("2025-12-31T15:30:00Z"), calendar: utc)).first?.id, "boundary")
    }

    func testLeapDayRemainsSeparateFromFollowingMonth() throws {
        let calendar = try calendar()
        let now = try date("2024-03-01T00:00:00Z")
        let index = CalendarDiaryIndex(entries: [
            entry("leap-day", dateString: "2024-02-29 23:59:00 +0900"),
            entry("march", dateString: "2024-03-01 00:00:00 +0900")
        ], calendar: calendar, now: now)
        XCTAssertEqual(index.entries(on: CalendarDay(date: try date("2024-02-29T12:00:00Z"), calendar: calendar)).first?.id, "leap-day")
        XCTAssertEqual(index.entries(on: CalendarDay(date: now, calendar: calendar)).first?.id, "march")
    }

    func testDayEntriesAreOrderedByActualTimeInsteadOfStoredString() throws {
        let calendar = try calendar()
        let now = try date("2026-09-15T00:00:00Z")
        let index = CalendarDiaryIndex(entries: [
            entry("earlier", dateString: "2026-09-15 11:00:00 +0900"),
            entry("later", dateString: "2026-09-15 03:00:00 +0000")
        ], calendar: calendar, now: now)
        XCTAssertEqual(index.entries(on: CalendarDay(date: now, calendar: calendar)).compactMap(\.id), ["later", "earlier"])
    }

    func testMovingDiaryReloadsBothOldAndNewDays() throws {
        let calendar = try calendar()
        let now = try date("2026-09-15T00:00:00Z")
        let old = CalendarDiaryIndex(entries: [entry("moved", dateString: "2026-09-14 09:00:00 +0900")], calendar: calendar, now: now)
        let new = CalendarDiaryIndex(entries: [entry("moved", dateString: "2026-09-15 09:00:00 +0900")], calendar: calendar, now: now)
        XCTAssertEqual(new.decorationDaysToReload(previous: old.decoratedDays), old.decoratedDays.union(new.decoratedDays))
        XCTAssertTrue(new.entries(on: CalendarDay(date: try date("2026-09-14T00:00:00Z"), calendar: calendar)).isEmpty)
    }

    func testInvalidDateKeepsLegacyTodayFallbackUsingInjectedClock() throws {
        let calendar = try calendar()
        let now = try date("2026-09-15T00:00:00Z")
        let index = CalendarDiaryIndex(entries: [entry("invalid-date", dateString: "invalid")], calendar: calendar, now: now)
        XCTAssertEqual(index.entries(on: CalendarDay(date: now, calendar: calendar)).first?.id, "invalid-date")
    }

    func testMonthGridRespectsFirstWeekdayAndContainsEveryLeapDay() throws {
        var calendar = try calendar()
        calendar.firstWeekday = 2
        let month = try XCTUnwrap(CalendarMonth(date: try date("2024-02-15T00:00:00Z"), calendar: calendar))
        XCTAssertEqual(month.cells.count % 7, 0)
        XCTAssertEqual(month.cells.prefix(3).compactMap { $0 }.count, 0)
        XCTAssertEqual(month.cells.compactMap { $0 }.count, 29)
        XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(month.cells.compactMap { $0 }.last)), 29)
    }
}
