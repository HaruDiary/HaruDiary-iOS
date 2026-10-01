import Foundation

/// How a month felt: how much was written and which moods the diaries carry.
struct MonthMoodSummary: Equatable {
    struct Mood: Equatable, Identifiable {
        /// The stored mood value (an asset name).
        let emotion: String
        let count: Int
        var id: String { emotion }
    }

    let daysWritten: Int
    let diaryCount: Int
    /// Most frequent first; equal counts follow the order of the mood picker.
    let moods: [Mood]

    var moodCount: Int { moods.reduce(0) { $0 + $1.count } }

    init(entriesByDay: [[DiaryEntry]]) {
        daysWritten = entriesByDay.filter { !$0.isEmpty }.count
        let entries = entriesByDay.flatMap { $0 }
        diaryCount = entries.count
        var counts: [String: Int] = [:]
        for entry in entries where !entry.emotion.isEmpty { counts[entry.emotion, default: 0] += 1 }
        let pickerOrder = DiaryConditions.emotions.map(\.value)
        func rank(_ emotion: String) -> Int { pickerOrder.firstIndex(of: emotion) ?? pickerOrder.count }
        moods = counts.map { Mood(emotion: $0.key, count: $0.value) }.sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if rank(lhs.emotion) != rank(rhs.emotion) { return rank(lhs.emotion) < rank(rhs.emotion) }
            return lhs.emotion < rhs.emotion
        }
    }
}
