import SwiftUI
import WidgetKit

/// Whether today's diary is written, and how far this month is filled. It shows days only, never what was
/// written: the home screen is seen by others, and the app can be locked.
struct DiaryStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DiaryWidgetShared.widgetKind, provider: DiaryStatusProvider()) { entry in
            DiaryStatusWidgetView(status: entry.status)
                .containerBackground(DiaryTheme.Colors.surface, for: .widget)
        }
        .configurationDisplayName("오늘의 일기")
        .description("오늘 일기를 썼는지, 이번 달에 며칠 썼는지 보여줘요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DiaryStatusEntry: TimelineEntry {
    let date: Date
    let status: DiaryWidgetStatus
}

struct DiaryStatusProvider: TimelineProvider {
    var store: any DiaryWidgetSnapshotStoring = UserDefaultsDiaryWidgetStore()
    var calendar: Calendar = .current

    func placeholder(in context: Context) -> DiaryStatusEntry {
        DiaryStatusEntry(date: Date(), status: Self.sample(calendar: calendar))
    }

    func getSnapshot(in context: Context, completion: @escaping (DiaryStatusEntry) -> Void) {
        // The widget gallery shows a filled example instead of an empty first run.
        let now = Date()
        completion(DiaryStatusEntry(date: now, status: context.isPreview ? Self.sample(calendar: calendar)
                                                                         : store.load().status(on: now, calendar: calendar)))
    }

    /// Now, then every time the line changes over the next days. Each midnight is among them,
    /// so "today" moves on without the app.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DiaryStatusEntry>) -> Void) {
        let snapshot = store.load()
        let now = Date()
        var dates = [now]
        for offset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            dates += DiaryWidgetPhrases.changeTimes(onDayOf: day, calendar: calendar).filter { $0 > now }
        }
        let entries = dates.map { DiaryStatusEntry(date: $0, status: snapshot.status(on: $0, calendar: calendar)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    static func sample(calendar: Calendar) -> DiaryWidgetStatus {
        let now = Date()
        let days = [0, 1, 2, 4, 5].compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
            .map { DiaryWidgetSnapshot.key(for: $0, calendar: calendar) }
        return DiaryWidgetSnapshot(writtenDays: days.sorted()).status(on: now, calendar: calendar)
    }
}

struct DiaryStatusWidgetView: View {
    let status: DiaryWidgetStatus
    @Environment(\.widgetFamily) private var family

    var body: some View {
        DiaryStatusContent(status: status, showsWeek: family == .systemMedium)
    }
}

/// What the widget draws; the medium size adds the last week.
struct DiaryStatusContent: View {
    let status: DiaryWidgetStatus
    let showsWeek: Bool

    var body: some View {
        if showsWeek {
            HStack(alignment: .center, spacing: 16) {
                summary
                Divider()
                week
            }
        } else {
            summary
        }
    }

    /// Today's date with whether its diary is written, a line to go with it, and the month as a count and a bar.
    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(status.month)월 \(status.day)일")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DiaryTheme.Colors.text)
                    Text(Self.weekdayNames[(status.weekday - 1) % 7] + "요일")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: status.wroteToday ? "checkmark.circle.fill" : "pencil.circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(DiaryTheme.Colors.brand)
            }
            Text(status.wroteToday ? "오늘 일기를 썼어요" : "아직 쓰지 않았어요")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DiaryTheme.Colors.brand)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 8)
            Text(status.phrase)
                .font(.system(size: 12))
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
            Spacer(minLength: 4)
            Text("이번 달 \(status.daysWrittenThisMonth)/\(status.daysInMonth)일")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
            GeometryReader { geometry in
                Capsule().fill(DiaryTheme.Colors.selection.opacity(0.6))
                    .overlay(alignment: .leading) {
                        Capsule().fill(DiaryTheme.Colors.brand)
                            .frame(width: geometry.size.width * monthShare)
                    }
            }
            .frame(height: 5)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.month)월 \(status.day)일 \(Self.weekdayNames[(status.weekday - 1) % 7])요일. \(status.wroteToday ? "오늘 일기를 썼어요" : "오늘 일기를 아직 쓰지 않았어요"). \(status.phrase) 이번 달에 \(status.daysInMonth)일 중 \(status.daysWrittenThisMonth)일 썼어요.")
    }

    private var monthShare: CGFloat {
        guard status.daysInMonth > 0 else { return 0 }
        return min(CGFloat(status.daysWrittenThisMonth) / CGFloat(status.daysInMonth), 1)
    }

    /// The last seven days: a filled circle for each day written.
    private var week: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("최근 7일")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
            HStack(spacing: 0) {
                ForEach(status.week) { day in
                    VStack(spacing: 5) {
                        Text(Self.weekdayNames[(day.weekday - 1) % 7])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DiaryTheme.Colors.secondaryText)
                        Text("\(day.day)")
                            .font(.system(size: 12, weight: day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isWritten ? DiaryTheme.Colors.onBrand : DiaryTheme.Colors.text)
                            .frame(width: 24, height: 24)
                            .background {
                                if day.isWritten {
                                    Circle().fill(DiaryTheme.Colors.brand)
                                } else if day.isToday {
                                    Circle().strokeBorder(DiaryTheme.Colors.brand, lineWidth: 1.5)
                                } else {
                                    Circle().fill(DiaryTheme.Colors.selection.opacity(0.45))
                                }
                            }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("최근 7일 중 \(status.week.filter(\.isWritten).count)일 썼어요.")
    }

    private static let weekdayNames = ["일", "월", "화", "수", "목", "금", "토"]
}
