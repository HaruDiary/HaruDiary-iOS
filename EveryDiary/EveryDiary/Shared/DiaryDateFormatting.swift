import Foundation

extension DateFormatter {
    static func createFormatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale(identifier: "ko-KR")
        formatter.timeZone = .current
        return formatter
    }
    
    static let yyyyMMddHHmmss: DateFormatter = createFormatter(dateFormat: "yyyy-MM-dd HH:mm:ss Z")
    static let yyyyMMdd: DateFormatter = createFormatter(dateFormat: "yyyy-MM-dd")
    static let yyyyMM: DateFormatter = createFormatter(dateFormat: "yyyy.MM")
    static let yyyyMMddE: DateFormatter = createFormatter(dateFormat: "yyyy. MM. dd(E)")
    static let yyyyMMDD: DateFormatter = createFormatter(dateFormat: "yyyy.MM.dd")
}

