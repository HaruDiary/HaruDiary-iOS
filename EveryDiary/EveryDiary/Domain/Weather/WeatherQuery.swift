import Foundation

/// Why current weather could not be loaded. Each case needs a different fix, so they are kept apart.
enum WeatherError: Error, Equatable {
    /// `Api.plist` has no OpenWeather key (local file missing, or the Xcode Cloud variable not set).
    case missingAPIKey
    /// OpenWeather rejected the key (HTTP 401).
    case invalidAPIKey
    /// Location permission denied, or no location within the time limit.
    case noLocation
    /// No response, e.g. offline or timed out.
    case network
    /// OpenWeather answered with an error status other than 401.
    case server(status: Int)
    /// A successful response that is not current-weather JSON.
    case decoding
}

/// Builds the OpenWeather current-weather request and reads its response, without networking or location.
enum WeatherQuery {
    static let requestTimeout: TimeInterval = 8

    /// nil when there is no API key, so no request is sent with an empty key.
    static func url(latitude: Double, longitude: Double, apiKey: String) -> URL? {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "appid", value: key),
            URLQueryItem(name: "lang", value: "kr"),
            URLQueryItem(name: "units", value: "metric")
        ]
        return components?.url
    }

    /// Reads the HTTP status first: an error body such as `{"cod":401,...}` is not weather and must not be
    /// reported as a decoding failure.
    static func parse(data: Data?, statusCode: Int?) -> Result<WeatherResponse, WeatherError> {
        guard let data, let statusCode else { return .failure(.network) }
        switch statusCode {
        case 200..<300:
            guard let response = try? JSONDecoder().decode(WeatherResponse.self, from: data) else { return .failure(.decoding) }
            return .success(response)
        case 401:
            return .failure(.invalidAPIKey)
        default:
            return .failure(.server(status: statusCode))
        }
    }
}
