import Foundation

// Built in the app only: the widget is given the finished snapshot and never sees a diary.
extension DiaryWidgetSnapshot {
    /// Trashed diaries and diaries whose date cannot be read count for nothing, as in the journey.
    init(entries: [DiaryEntry], userID: String? = nil, calendar: Calendar, today: Date) {
        self.userID = userID
        let oldest = calendar.date(byAdding: .day, value: -Self.keptDays, to: calendar.startOfDay(for: today)) ?? today
        var days = Set<Int>()
        for entry in entries where !entry.isDeleted {
            guard let date = DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString), date >= oldest else { continue }
            days.insert(Self.key(for: date, calendar: calendar))
        }
        writtenDays = days.sorted()
    }
}
