import SwiftUI

struct CalendarDiaryRow: View {
    let entry: DiaryEntry
    let calendar: Calendar
    let imageLoader: any CalendarImageLoading

    var body: some View {
        HStack(alignment: .top, spacing: DiaryTheme.Spacing.medium) {
            CalendarDiaryThumbnail(entry: entry, imageLoader: imageLoader)
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
                Text(entry.title)
                    .font(DiaryTheme.Fonts.section)
                    .foregroundStyle(DiaryTheme.Colors.text)
                    .lineLimit(2)
                HStack(spacing: DiaryTheme.Spacing.small) {
                    if !entry.weather.isEmpty {
                        Image(entry.weather).resizable().scaledToFit().frame(width: 20, height: 20)
                    }
                    if !entry.emotion.isEmpty {
                        Image(entry.emotion).resizable().scaledToFit().frame(width: 20, height: 20)
                    }
                    Text(timeText).font(DiaryTheme.Fonts.caption).foregroundStyle(DiaryTheme.Colors.secondaryText)
                }
                Text(entry.content)
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(DiaryTheme.Spacing.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var timeText: String {
        guard let date = DateFormatter.yyyyMMddHHmmss.date(from: entry.dateString) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
}

private struct CalendarDiaryThumbnail: View {
    let entry: DiaryEntry
    let imageLoader: any CalendarImageLoading
    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            DiaryTheme.Colors.selection.opacity(0.5)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if isLoading {
                ProgressView()
            } else if !entry.emotion.isEmpty {
                Image(entry.emotion).resizable().scaledToFit().padding(DiaryTheme.Spacing.screen)
            } else {
                Image(systemName: "book.closed").foregroundStyle(DiaryTheme.Colors.brand)
            }
        }
        .frame(width: DiaryTheme.Size.thumbnail, height: DiaryTheme.Size.thumbnail)
        .clipShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .accessibilityHidden(true)
        .task(id: entry.imageURL?.first) {
            image = nil
            guard let value = entry.imageURL?.first, let url = URL(string: value) else {
                isLoading = false
                return
            }
            isLoading = true
            let loaded = await imageLoader.image(for: url)
            guard !Task.isCancelled else { return }
            image = loaded
            isLoading = false
        }
    }
}
