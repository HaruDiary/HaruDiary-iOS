#if DEBUG
import Foundation

enum CalendarPreviewData {
    static let now = Date(timeIntervalSince1970: 1_789_430_400)

    static var entries: [DiaryEntry] {
        var first = DiaryEntry(title: "기분 좋은 산책", content: "퇴근 후 강변을 따라 걸었어요. 선선한 바람이 좋았어요.", date: now, emotion: "Grinning face", weather: "u_sun")
        first.id = "preview-walk"
        var second = first
        second.id = "preview-coffee"
        second.title = "오늘의 작은 행복"
        second.content = "좋아하는 커피와 함께 잠깐 쉬어 갔어요."
        second.emotion = "Smiling face with smiling eyes"
        return [first, second]
    }
}
#endif
