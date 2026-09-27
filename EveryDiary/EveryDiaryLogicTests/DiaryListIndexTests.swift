import Foundation
import XCTest

final class DiaryListIndexTests: XCTestCase {
    private func calendar(hoursFromGMT: Int = 9) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: hoursFromGMT * 3600))
        return calendar
    }

    private func entry(_ id: String, _ dateString: String, title: String? = nil, content: String = "본문", isDeleted: Bool = false) -> DiaryEntry {
        var entry = DiaryEntry(title: title ?? id, content: content, date: Date(timeIntervalSince1970: 0), emotion: "", weather: "")
        entry.id = id
        entry.dateString = dateString
        entry.isDeleted = isDeleted
        return entry
    }

    func testSectionsAreNewestMonthFirstAcrossYearBoundary() throws {
        let sections = DiaryListIndex.sections(from: [
            entry("dec", "2025-12-31 10:00:00 +0900"),
            entry("sep", "2026-09-01 10:00:00 +0900"),
            entry("jan", "2026-01-01 10:00:00 +0900"),
        ], calendar: try calendar())

        XCTAssertEqual(sections.map(\.id), ["2026.09", "2026.01", "2025.12"])
        XCTAssertEqual(sections.map { $0.entries.map(\.id) }, [["sep"], ["jan"], ["dec"]])
    }

    func testEntriesInMonthAreNewestFirstAndSameTimeUsesDocumentID() throws {
        let sections = DiaryListIndex.sections(from: [
            entry("morning", "2026-09-15 08:00:00 +0900"),
            entry("b-night", "2026-09-15 21:00:00 +0900"),
            entry("a-night", "2026-09-15 21:00:00 +0900"),
            entry("earlier", "2026-09-02 12:00:00 +0900"),
        ], calendar: try calendar())

        XCTAssertEqual(sections.first?.entries.map(\.id), ["a-night", "b-night", "morning", "earlier"])
    }

    func testDeletedAndUnparseableEntriesAreHidden() throws {
        let sections = DiaryListIndex.sections(from: [
            entry("visible", "2026-09-15 08:00:00 +0900"),
            entry("trashed", "2026-09-15 09:00:00 +0900", isDeleted: true),
            entry("broken", "2026/09/15"),
        ], calendar: try calendar())

        XCTAssertEqual(sections.flatMap(\.entries).map(\.id), ["visible"])
    }

    func testMonthUsesInjectedTimeZone() throws {
        let lateUTC = [entry("edge", "2026-09-30 23:30:00 +0000")]

        XCTAssertEqual(DiaryListIndex.sections(from: lateUTC, calendar: try calendar(hoursFromGMT: 0)).map(\.id), ["2026.09"])
        XCTAssertEqual(DiaryListIndex.sections(from: lateUTC, calendar: try calendar(hoursFromGMT: 9)).map(\.id), ["2026.10"])
    }

    func testSearchMatchesTitleOrContentIgnoringCase() throws {
        let entries = [
            entry("title", "2026-09-15 08:00:00 +0900", title: "Morning Walk"),
            entry("content", "2026-09-14 08:00:00 +0900", title: "일상", content: "강변 WALK 산책"),
            entry("other", "2026-09-13 08:00:00 +0900", title: "커피", content: "카페"),
        ]

        let sections = DiaryListIndex.sections(from: entries, matching: "walk", calendar: try calendar())

        XCTAssertEqual(sections.flatMap(\.entries).map(\.id), ["title", "content"])
    }

    func testSearchNeverShowsTrashedDiaries() throws {
        let entries = [
            entry("kept", "2026-09-15 08:00:00 +0900", title: "산책"),
            entry("trashed", "2026-09-14 08:00:00 +0900", title: "산책", isDeleted: true),
        ]

        let sections = DiaryListIndex.sections(from: entries, matching: "산책", calendar: try calendar())

        XCTAssertEqual(sections.flatMap(\.entries).map(\.id), ["kept"])
    }

    func testBlankQueryShowsEveryVisibleDiary() throws {
        let entries = [
            entry("first", "2026-09-15 08:00:00 +0900", title: "공백 없음"),
            entry("second", "2026-09-14 08:00:00 +0900", title: "다른 일기"),
        ]

        let sections = DiaryListIndex.sections(from: entries, matching: "  \n", calendar: try calendar())

        XCTAssertEqual(sections.flatMap(\.entries).count, 2)
        XCTAssertEqual(DiaryListIndex.normalizedQuery("  산책 "), "산책")
    }
}
