import Foundation

/// A place as diaries and photo metadata store it: "37.5665, 126.978".
struct DiaryCoordinate: Equatable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init?(stored: String?) {
        guard let parts = stored?.components(separatedBy: ", "), parts.count == 2,
              let latitude = Double(parts[0]), let longitude = Double(parts[1]) else { return nil }
        self.init(latitude: latitude, longitude: longitude)
    }

    var stored: String { "\(latitude), \(longitude)" }
}

/// The text and choices being written. Photos are kept by the editor, since they hold images.
struct DiaryDraft: Equatable {
    var title = ""
    var content = ""
    var date: Date
    var emotion = ""
    var weather = ""
    /// True when the user chose the photos' place over the place the diary was written.
    var useMetadataLocation = false
    var currentLocationInfo: String?

    init(date: Date) {
        self.date = date
    }

    init(entry: DiaryEntry) {
        title = entry.title
        content = entry.content
        date = entry.date
        emotion = entry.emotion
        weather = entry.weather
        useMetadataLocation = entry.useMetadataLocation
        currentLocationInfo = entry.currentLocationInfo
    }

    /// The previous editor refused only an empty title, not one of spaces.
    var isTitleMissing: Bool { title.isEmpty }

    /// A new diary in the stored shape. Photos are added by saving.
    func newEntry(weather stamp: DiaryWeatherStamp?) -> DiaryEntry {
        var entry = DiaryEntry(title: title, content: content, dateString: DateFormatter.yyyyMMddHHmmss.string(from: date),
                               emotion: emotion, weather: weather, imageURL: [],
                               useMetadataLocation: useMetadataLocation, currentLocationInfo: currentLocationInfo ?? "")
        stamp?.apply(to: &entry)
        return entry
    }

    /// `original` with the edited fields; everything else (ID, owner, weather text, trash state) stays as stored.
    func applied(to original: DiaryEntry) -> DiaryEntry {
        var entry = original
        entry.title = title
        entry.content = content
        entry.dateString = DateFormatter.yyyyMMddHHmmss.string(from: date)
        entry.emotion = emotion
        entry.weather = weather
        entry.useMetadataLocation = useMetadataLocation
        entry.currentLocationInfo = currentLocationInfo
        return entry
    }
}

/// The weather a new diary stores: the current weather when it is written for today, otherwise "Unknown" and 0,
/// the values saving stored before when it looked the weather up itself.
enum DiaryWeatherStamp: Equatable {
    case loaded(description: String, celsius: Double)
    case unavailable

    /// Nil while the editor's lookup is still running: saving then looks the weather up as it did before.
    static func forDiary(on date: Date, now: Date, calendar: Calendar,
                         lookup: Result<WeatherResponse, WeatherError>?) -> DiaryWeatherStamp? {
        guard calendar.isDate(date, inSameDayAs: now) else { return .unavailable }
        switch lookup {
        case nil: return nil
        case .success(let response):
            return .loaded(description: response.weather.first?.description ?? "Unknown", celsius: response.main.temp)
        case .failure: return .unavailable
        }
    }

    func apply(to entry: inout DiaryEntry) {
        switch self {
        case .loaded(let description, let celsius):
            entry.weatherDescription = description
            entry.weatherTemp = celsius
        case .unavailable:
            entry.weatherDescription = "Unknown"
            entry.weatherTemp = 0
        }
    }
}

/// Photos picked with the system picker, which is given the current photos to show them as selected.
enum DiaryPhotoPicking {
    static let limit = 3

    /// Photos still picked keep their place, newly picked ones follow in picking order.
    /// A stored photo without an identifier cannot be shown in the picker, so the picker never removes it.
    static func merge<Photo>(current: [Photo], picked: [Photo], pickedIDs: [String],
                             id: (Photo) -> String?) -> [Photo] {
        let pickedSet = Set(pickedIDs)
        let kept = current.filter { photo in id(photo).map(pickedSet.contains) ?? true }
        let keptIDs = Set(kept.compactMap(id))
        let added = picked.filter { photo in id(photo).map { !keptIDs.contains($0) } ?? false }
        return kept + added
    }

    /// How many photos the picker may hold: the photos it cannot show still count toward the limit.
    static func pickerLimit<Photo>(current: [Photo], id: (Photo) -> String?) -> Int {
        max(0, limit - current.filter { id($0) == nil }.count)
    }
}
