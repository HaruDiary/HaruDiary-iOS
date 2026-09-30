import XCTest

final class WeatherConditionTextTests: XCTestCase {
    func testKnownConditionsAreKorean() {
        XCTAssertEqual(WeatherConditionText.description(condition: "clear", fallback: "Clear"), "맑음")
        XCTAssertEqual(WeatherConditionText.description(condition: "mostlyCloudy", fallback: "Mostly Cloudy"), "대체로 흐림")
        XCTAssertEqual(WeatherConditionText.description(condition: "heavyRain", fallback: "Heavy Rain"), "폭우")
    }

    func testConditionAddedLaterFallsBackToWeatherKitText() {
        XCTAssertEqual(WeatherConditionText.description(condition: "somethingNew", fallback: "Something New"), "Something New")
    }

    func testEveryConditionHasText() {
        XCTAssertEqual(WeatherConditionText.korean.count, 34)
        XCTAssertFalse(WeatherConditionText.korean.values.contains(where: \.isEmpty))
    }

    func testResultKeepsTheShapeCallersRead() {
        let response = WeatherResponse(description: "맑음", celsius: 21.4)
        XCTAssertEqual(response.weather.first?.description, "맑음")
        XCTAssertEqual(response.main.temp, 21.4, accuracy: 0.001)
    }

    func testOfflineIsNetworkAndOtherFailuresAreUnavailable() {
        XCTAssertEqual(WeatherError.kind(of: URLError(.notConnectedToInternet)), .network)
        XCTAssertEqual(WeatherError.kind(of: NSError(domain: "WeatherDaemon", code: 2)), .unavailable)
    }

    func testOnlyTodaysDiaryUsesCurrentWeather() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 0, minute: 30)))
        let lateToday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 59)))
        let lateYesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 23, minute: 59)))
        XCTAssertTrue(WeatherError.appliesToDiary(on: lateToday, now: now, calendar: calendar))
        XCTAssertFalse(WeatherError.appliesToDiary(on: lateYesterday, now: now, calendar: calendar))
    }
}
