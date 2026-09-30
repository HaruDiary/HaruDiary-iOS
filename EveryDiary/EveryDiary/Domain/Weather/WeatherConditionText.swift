import Foundation

/// Why current weather could not be loaded. Each case needs a different fix, so they are kept apart.
enum WeatherError: Error, Equatable {
    /// Location permission denied, or no location within the time limit.
    case noLocation
    /// No response, e.g. offline or timed out.
    case network
    /// WeatherKit refused or failed, e.g. the WeatherKit capability is not enabled for the App ID.
    case unavailable

    static func kind(of error: Error) -> WeatherError {
        error is URLError ? .network : .unavailable
    }
}

/// Korean text for WeatherKit conditions, kept apart from WeatherKit so it can be tested and stays the same
/// whatever language the device uses. Diaries store this text in `weatherDescription`, as they stored
/// OpenWeather's Korean description before.
enum WeatherConditionText {
    /// `condition` is a `WeatherKit.WeatherCondition` raw value.
    static func description(condition: String, fallback: String) -> String {
        korean[condition] ?? fallback
    }

    static let korean: [String: String] = [
        "blizzard": "눈보라",
        "blowingDust": "황사",
        "blowingSnow": "날리는 눈",
        "breezy": "산들바람",
        "clear": "맑음",
        "cloudy": "흐림",
        "drizzle": "이슬비",
        "flurries": "약한 눈",
        "foggy": "안개",
        "freezingDrizzle": "어는 이슬비",
        "freezingRain": "어는 비",
        "frigid": "혹한",
        "hail": "우박",
        "haze": "연무",
        "heavyRain": "폭우",
        "heavySnow": "폭설",
        "hot": "폭염",
        "hurricane": "허리케인",
        "isolatedThunderstorms": "곳에 따라 뇌우",
        "mostlyClear": "대체로 맑음",
        "mostlyCloudy": "대체로 흐림",
        "partlyCloudy": "구름 조금",
        "rain": "비",
        "scatteredThunderstorms": "산발적 뇌우",
        "sleet": "진눈깨비",
        "smoky": "연기",
        "snow": "눈",
        "strongStorms": "강한 폭풍",
        "sunFlurries": "햇빛 속 약한 눈",
        "sunShowers": "여우비",
        "thunderstorms": "뇌우",
        "tropicalStorm": "열대 폭풍",
        "windy": "강풍",
        "wintryMix": "비와 눈"
    ]
}

extension WeatherResponse {
    /// The shape the editor and diary saving already read: `weather.first?.description` and `main.temp` (°C).
    init(description: String, celsius: Double) {
        self.init(weather: [Weather(description: description)], main: Main(temp: celsius))
    }
}
