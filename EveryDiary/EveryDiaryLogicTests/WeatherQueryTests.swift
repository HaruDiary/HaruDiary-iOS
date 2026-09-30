import XCTest

final class WeatherQueryTests: XCTestCase {
    private func json(_ text: String) -> Data { Data(text.utf8) }

    func testRejectedKeyIsReportedAsInvalidKeyNotDecoding() {
        // The response the app got with the empty key committed in Api.plist; it used to surface as decodingError.
        let body = json(#"{"cod":401,"message":"Invalid API key. Please see https://openweathermap.org/faq#error401 for more info."}"#)
        XCTAssertEqual(WeatherQuery.parse(data: body, statusCode: 401), .failure(.invalidAPIKey))
    }

    func testNoRequestIsBuiltWithoutAKey() {
        XCTAssertNil(WeatherQuery.url(latitude: 37.57, longitude: 126.98, apiKey: ""))
        XCTAssertNil(WeatherQuery.url(latitude: 37.57, longitude: 126.98, apiKey: "  \n"))
    }

    func testRequestAsksForKoreanMetricWeatherAtTheLocation() throws {
        let url = try XCTUnwrap(WeatherQuery.url(latitude: 37.57, longitude: 126.98, apiKey: "test-key"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.host, "api.openweathermap.org")
        XCTAssertEqual(query["lat"], "37.57")
        XCTAssertEqual(query["lon"], "126.98")
        XCTAssertEqual(query["appid"], "test-key")
        XCTAssertEqual(query["lang"], "kr")
        XCTAssertEqual(query["units"], "metric")
    }

    func testCurrentWeatherIsRead() throws {
        let body = json(#"{"weather":[{"id":800,"main":"Clear","description":"맑음","icon":"01d"}],"main":{"temp":21.4,"humidity":40},"name":"Seoul","cod":200}"#)
        let response = try WeatherQuery.parse(data: body, statusCode: 200).get()
        XCTAssertEqual(response.weather.first?.description, "맑음")
        XCTAssertEqual(response.main.temp, 21.4, accuracy: 0.001)
    }

    func testOtherFailuresStayApart() {
        XCTAssertEqual(WeatherQuery.parse(data: json(#"{"cod":429}"#), statusCode: 429), .failure(.server(status: 429)))
        XCTAssertEqual(WeatherQuery.parse(data: json("<html>"), statusCode: 200), .failure(.decoding))
        XCTAssertEqual(WeatherQuery.parse(data: nil, statusCode: nil), .failure(.network))
    }
}
