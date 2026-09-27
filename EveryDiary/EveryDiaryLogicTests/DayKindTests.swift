import Foundation
import XCTest

final class DayKindTests: XCTestCase {
    private func kind(_ year: Int, _ month: Int, _ day: Int) throws -> DayKind {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 9 * 3600))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        return DayKind(date: date, calendar: calendar)
    }

    func testWeekendsAreMarkedSaturdayAndHoliday() throws {
        XCTAssertEqual(try kind(2026, 9, 19), .saturday)
        XCTAssertEqual(try kind(2026, 9, 20), .holiday)
        XCTAssertEqual(try kind(2026, 9, 21), .weekday)
    }

    func testLunarAndFixedHolidaysOnWeekdaysAreHolidays() throws {
        XCTAssertEqual(try kind(2026, 9, 24), .holiday)  // 추석 연휴 (Thu)
        XCTAssertEqual(try kind(2026, 12, 25), .holiday) // 성탄절 (Fri)
        XCTAssertEqual(try kind(2027, 2, 8), .holiday)   // 설날 연휴 (Mon)
    }

    func testSubstituteAndTemporaryHolidaysAreHolidays() throws {
        XCTAssertEqual(try kind(2026, 10, 5), .holiday)  // 개천절 대체공휴일
        XCTAssertEqual(try kind(2025, 6, 3), .holiday)   // 대통령 선거
        XCTAssertEqual(try kind(2027, 2, 9), .holiday)   // 설날 대체공휴일
    }

    func testHolidayOnSaturdayIsRedNotBlue() throws {
        XCTAssertEqual(try kind(2026, 9, 26), .holiday)  // 추석 연휴 (Sat)
    }

    func testNewlyDesignatedHolidaysStartOnlyWhenAnnounced() throws {
        XCTAssertEqual(try kind(2026, 7, 17), .holiday)  // 제헌절, 2026년 재지정
        XCTAssertEqual(try kind(2025, 7, 17), .weekday)
    }

    func testYearsWithoutHolidayDataOnlyMarkWeekends() throws {
        XCTAssertFalse(KoreanPublicHolidays.coveredYears.contains(2023))
        XCTAssertEqual(try kind(2023, 12, 25), .weekday)
        XCTAssertEqual(try kind(2023, 12, 24), .holiday) // Sunday
    }
}
