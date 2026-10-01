import Foundation

/// The diaries as one text file to keep or move elsewhere: oldest first, in the order they were lived.
/// Photos are not in the file; each diary says how many it has.
enum DiaryExport {
    static let fileExtension = "txt"

    static func fileName(exportedAt: Date, calendar: Calendar) -> String {
        "하루일기-\(format(exportedAt, "yyyyMMdd", calendar)).\(fileExtension)"
    }

    /// Diaries in the trash and diaries whose stored date cannot be read are left out, as in the list.
    static func exportable(_ entries: [DiaryEntry]) -> [(entry: DiaryEntry, date: Date)] {
        entries.compactMap { entry -> (entry: DiaryEntry, date: Date)? in
            guard !entry.isDeleted, let date = DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString) else { return nil }
            return (entry, date)
        }.sorted { lhs, rhs in
            lhs.date == rhs.date ? (lhs.entry.id ?? "") < (rhs.entry.id ?? "") : lhs.date < rhs.date
        }
    }

    static func text(from entries: [DiaryEntry], exportedAt: Date, calendar: Calendar) -> String {
        let diaries = exportable(entries)
        var lines = ["하루일기", "내보낸 날: \(format(exportedAt, "yyyy년 M월 d일", calendar)) · 일기 \(diaries.count)개"]
        for diary in diaries {
            let entry = diary.entry
            lines.append("")
            lines.append("────────────────")
            lines.append(format(diary.date, "yyyy년 M월 d일 EEEE a h:mm", calendar))
            var conditions: [String] = []
            if !entry.emotion.isEmpty { conditions.append("기분: \(DiaryConditions.emotionLabel(entry.emotion) ?? entry.emotion)") }
            if !entry.weather.isEmpty { conditions.append("날씨: \(DiaryConditions.weatherLabel(entry.weather) ?? entry.weather)") }
            if !conditions.isEmpty { lines.append(conditions.joined(separator: " · ")) }
            lines.append("")
            lines.append(entry.title)
            if !entry.content.isEmpty {
                lines.append("")
                lines.append(entry.content)
            }
            if let photos = entry.imageURL?.count, photos > 0 {
                lines.append("")
                lines.append("(사진 \(photos)장은 이 파일에 들어 있지 않아요)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func format(_ date: Date, _ pattern: String, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
