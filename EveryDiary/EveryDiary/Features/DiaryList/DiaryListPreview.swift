#if DEBUG
import SwiftUI

@MainActor
private struct DiaryListPreviewView: View {
    let viewModel: DiaryListViewModel

    init(mode: DiaryListPreviewRepository.Mode, query: String = "") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .current
        viewModel = DiaryListViewModel(
            repository: DiaryListPreviewRepository(mode: mode), session: DiaryListPreviewSession(),
            trash: DiaryListPreviewTrash(), calendar: calendar, now: { CalendarPreviewData.now }
        )
        viewModel.query = query
    }

    var body: some View {
        DiaryListView(
            viewModel: viewModel, imageLoader: DiaryListPreviewImageLoader(),
            onSelectDiary: { _ in }, onEditDiary: { _ in }, onWriteDiary: {}, onOpenSettings: {}
        )
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

@MainActor
private final class DiaryListPreviewRepository: DiaryReadingRepository {
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
                continuation.finish(throwing: NSError(domain: "DiaryListPreview", code: 1))
            }
        }
    }
}

@MainActor
private final class DiaryListPreviewSession: DiaryUserSession {
    func observeUserIDs() -> AsyncStream<String?> {
        AsyncStream { $0.yield("preview-user") }
    }
}

@MainActor
private final class DiaryListPreviewTrash: DiaryTrashing {
    func moveToTrash(diaryID: String, userID: String, at date: Date) async throws {}
    func restore(diaryID: String, userID: String) async throws {}
    func deletePermanently(diaryID: String, userID: String, imageURLs: [String], condition: PermanentDeletionCondition) async throws -> PhotoCleanup { PhotoCleanup() }
}

@MainActor
private final class DiaryListPreviewImageLoader: CalendarImageLoading {
    func image(for url: URL) async -> UIImage? { nil }
}

#Preview("일기 목록 · 기록") { DiaryListPreviewView(mode: .content) }
#Preview("일기 목록 · 검색") { DiaryListPreviewView(mode: .content, query: "커피") }
#Preview("일기 목록 · 빈 상태") { DiaryListPreviewView(mode: .empty) }
#Preview("일기 목록 · 조회 실패") { DiaryListPreviewView(mode: .failure) }
#endif
