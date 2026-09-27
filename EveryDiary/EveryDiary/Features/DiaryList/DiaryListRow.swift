import SwiftUI

struct DiaryListRow: View {
    let entry: DiaryEntry
    let calendar: Calendar
    let imageLoader: any CalendarImageLoading
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Accessibility sizes stack the columns so titles are not squeezed into a narrow column.
    private var columns: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DiaryTheme.Spacing.small))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DiaryTheme.Spacing.medium))
    }

    var body: some View {
        columns {
            dateColumn
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
                HStack(spacing: DiaryTheme.Spacing.small) {
                    if !entry.weather.isEmpty {
                        Image(entry.weather).resizable().scaledToFit().frame(width: 20, height: 20)
                    }
                    if !entry.emotion.isEmpty {
                        Image(entry.emotion).resizable().scaledToFit().frame(width: 20, height: 20)
                    }
                }
                .accessibilityHidden(true)
                columns {
                    if let url = thumbnailURL {
                        DiaryListThumbnail(url: url, imageLoader: imageLoader)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(DiaryTheme.Fonts.section)
                            .foregroundStyle(DiaryTheme.Colors.text)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        Text(entry.content)
                            .font(.subheadline)
                            .foregroundStyle(DiaryTheme.Colors.secondaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DiaryTheme.Spacing.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .contentShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(accessibilityDate), \(entry.title)")
        .accessibilityHint("일기를 엽니다. 길게 누르면 수정하거나 휴지통으로 옮길 수 있어요.")
    }

    @ViewBuilder
    private var dateColumn: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text("\(dayText)일 \(weekdayText)")
                .font(DiaryTheme.Fonts.caption.weight(.semibold))
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
        } else {
            VStack(spacing: 2) {
                Text(dayText).font(.title3.weight(.bold)).foregroundStyle(DiaryTheme.Colors.text)
                Text(weekdayText).font(DiaryTheme.Fonts.caption).foregroundStyle(DiaryTheme.Colors.secondaryText)
            }
            .frame(minWidth: 32)
        }
    }

    private var date: Date? {
        DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString)
    }

    private var thumbnailURL: URL? {
        entry.imageURL?.first.flatMap(URL.init(string:))
    }

    private var dayText: String {
        date.map { String(calendar.component(.day, from: $0)) } ?? ""
    }

    private var weekdayText: String {
        format("E")
    }

    private var accessibilityDate: String {
        format("M월 d일 EEEE")
    }

    private func format(_ pattern: String) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

private struct DiaryListThumbnail: View {
    let url: URL
    let imageLoader: any CalendarImageLoading
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            DiaryTheme.Colors.selection.opacity(0.5)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "photo").foregroundStyle(DiaryTheme.Colors.secondaryText)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: DiaryTheme.Spacing.small))
        .accessibilityHidden(true)
        .task(id: url) {
            image = nil
            isLoading = true
            let loaded = await imageLoader.image(for: url)
            // A reused row may have moved to another URL; its cancelled task must not show the old image.
            guard !Task.isCancelled else { return }
            image = loaded
            isLoading = false
        }
    }
}
