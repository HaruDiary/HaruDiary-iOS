import Foundation

struct DiaryEntry: Codable {
    var id: String?
    var title: String
    var content: String
    var dateString: String
    var emotion: String
    var weather: String
    var weatherDescription: String?
    var weatherTemp: Double?
    var imageURL: [String]?
    var userID: String?
    var isDeleted: Bool = false
    var deleteDate: Date?
    var useMetadataLocation: Bool = false
    var currentLocationInfo: String?
}

extension DiaryEntry {
    var date: Date {
        return DateFormatter.yyyyMMddHHmmss.date(from: dateString) ?? Date()
    }
    
    init(title: String, content: String, date: Date, emotion: String, weather: String, imageURL: [String]? = nil, useMetaDataLocation: Bool = false, currentLocationInfo: String? = nil) {
        self.title = title
        self.content = content
        self.dateString = DateFormatter.yyyyMMddHHmmss.string(from: date)
        self.emotion = emotion
        self.weather = weather
        self.imageURL = imageURL
        self.useMetadataLocation = useMetaDataLocation
        self.currentLocationInfo = currentLocationInfo
    }
}

