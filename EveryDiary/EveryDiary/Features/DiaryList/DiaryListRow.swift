import SwiftUI

/// A short status shown at the end of the title line, e.g. the days left in the trash.
struct DiaryRowBadge: Equatable {
    let text: String
    var isUrgent = false
}

struct DiaryListRow: View {
    let entry: DiaryEntry
    let calendar: Calendar
    let imageLoader: any CalendarImageLoading
    var badge: DiaryRowBadge?
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
            // Title and content always start right after the date, whatever the diary has; its weather, mood
            // and photo sit at the trailing edge.
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
                HStack(spacing: DiaryTheme.Spacing.small) {
                    Text(entry.title)
                        .font(DiaryTheme.Fonts.section)
                        .foregroundStyle(DiaryTheme.Colors.text)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                        .truncationMode(.tail)
                    if let badge {
                        // The title gives up space first so the badge always stays readable.
                        Text(badge.text)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(badge.isUrgent ? DiaryTheme.Colors.holiday : DiaryTheme.Colors.secondaryText)
                            .padding(.horizontal, DiaryTheme.Spacing.small)
                            .padding(.vertical, 3)
                            .background((badge.isUrgent ? DiaryTheme.Colors.holiday : DiaryTheme.Colors.secondaryText).opacity(0.12), in: Capsule())
                            .fixedSize()
                            .layoutPriority(1)
                    }
                }
                Text(entry.content)
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    // Beside a photo the text can use the photo's height (about three lines).
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : (thumbnailURL == nil ? 2 : 3))
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if hasIcons || thumbnailURL != nil {
                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: DiaryTheme.Spacing.small) {
                    if hasIcons { icons.accessibilityHidden(true) }
                    if let url = thumbnailURL {
                        DiaryListThumbnail(url: url, imageLoader: imageLoader)
                    }
                }
            }
        }
        .padding(DiaryTheme.Spacing.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .contentShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel([accessibilityDate, entry.title, badge?.text].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("일기를 엽니다. 길게 누르면 수정하거나 휴지통으로 옮길 수 있어요.")
    }

    @ViewBuilder
    private var dateColumn: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text("\(dayText)일 \(weekdayText)")
                .font(DiaryTheme.Fonts.caption.weight(.semibold))
                .foregroundStyle(dayColor ?? DiaryTheme.Colors.secondaryText)
        } else {
            VStack(spacing: 2) {
                Text(dayText).font(.title3.weight(.bold)).foregroundStyle(dayColor ?? DiaryTheme.Colors.text)
                Text(weekdayText).font(.footnote.weight(.medium)).foregroundStyle(dayColor ?? DiaryTheme.Colors.secondaryText)
            }
            .frame(minWidth: 32)
        }
    }

    private var hasIcons: Bool {
        !entry.weather.isEmpty || !entry.emotion.isEmpty
    }

    private var icons: some View {
        HStack(spacing: DiaryTheme.Spacing.small) {
            if !entry.weather.isEmpty {
                DiaryWeatherIcon(name: entry.weather)
            }
            if !entry.emotion.isEmpty {
                Image(entry.emotion).resizable().scaledToFit().frame(width: 20, height: 20)
            }
        }
    }

    private var dayColor: Color? {
        guard let date else { return nil }
        switch DayKind(date: date, calendar: calendar) {
        case .weekday: return nil
        case .saturday: return DiaryTheme.Colors.saturday
        case .holiday: return DiaryTheme.Colors.holiday
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
    static let side: CGFloat = 64
    let url: URL
    let imageLoader: any CalendarImageLoading
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            DiaryTheme.Colors.selection.opacity(0.5)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .transition(.opacity)
            } else if isLoading {
                PhotoSkeleton(cornerRadius: 0)
            } else {
                Image(systemName: "photo").foregroundStyle(DiaryTheme.Colors.secondaryText)
            }
        }
        .frame(width: Self.side, height: Self.side)
        .clipShape(RoundedRectangle(cornerRadius: DiaryTheme.Spacing.small))
        .accessibilityHidden(true)
        .task(id: url) {
            image = nil
            isLoading = true
            let loaded = await imageLoader.image(for: url)
            // A reused row may have moved to another URL; its cancelled task must not show the old image.
            guard !Task.isCancelled else { return }
            withAnimation(PhotoSkeleton.fadeIn) {
                image = loaded
                isLoading = false
            }
        }
    }
}
