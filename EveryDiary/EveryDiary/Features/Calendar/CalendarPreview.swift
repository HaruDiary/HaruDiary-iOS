#if DEBUG
import SwiftUI

@MainActor
private struct CalendarPreviewView: View {
    let viewModel: CalendarViewModel

    init(mode: CalendarPreviewRepository.Mode) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .current
        viewModel = CalendarViewModel(
            repository: CalendarPreviewRepository(mode: mode),
            session: CalendarPreviewSession(), calendar: calendar,
            now: { CalendarPreviewData.now }
        )
    }

    var body: some View {
        CalendarView(
            viewModel: viewModel, imageLoader: CalendarPreviewImageLoader(),
            onSelectDiary: { _ in }, onOpenDayList: {}, onWriteDiary: {}, onOpenSettings: {}
        )
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

@MainActor
private final class CalendarPreviewRepository: DiaryReadingRepository {
    enum Mode { case content, empty, failure }
    private let mode: Mode

    init(mode: Mode) { self.mode = mode }

    func observeDiaries(userID: String) -> AsyncThrowingStream<[DiaryEntry], Error> {
        AsyncThrowingStream { continuation in
            switch mode {
            case .content:
                continuation.yield(CalendarPreviewData.entries)
            case .empty:
                continuation.yield([])
            case .failure:
                continuation.finish(throwing: NSError(domain: "CalendarPreview", code: 1))
            }
        }
    }
}

@MainActor
private final class CalendarPreviewSession: DiaryUserSession {
    func observeUserIDs() -> AsyncStream<String?> {
        AsyncStream { $0.yield("preview-user") }
    }
}

@MainActor
private final class CalendarPreviewImageLoader: CalendarImageLoading {
    func image(for url: URL) async -> UIImage? { nil }
}

#Preview("Calendar · 기록") { CalendarPreviewView(mode: .content) }
#Preview("Calendar · 빈 상태") { CalendarPreviewView(mode: .empty) }
#Preview("Calendar · 조회 실패") { CalendarPreviewView(mode: .failure) }
#endif
