import Foundation

@MainActor
struct TrashModule {
    let viewModel: TrashViewModel
    let imageLoader: any CalendarImageLoading

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, trash: any DiaryTrashing,
         imageLoader: any CalendarImageLoading, calendar: Calendar, now: @escaping () -> Date) {
        viewModel = TrashViewModel(repository: repository, session: session, trash: trash, calendar: calendar, now: now)
        self.imageLoader = imageLoader
    }
}
