import Foundation

@MainActor
struct DiaryListModule {
    let viewModel: DiaryListViewModel
    let imageLoader: any CalendarImageLoading

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, trash: any DiaryTrashing,
         imageLoader: any CalendarImageLoading, calendar: Calendar, now: @escaping () -> Date) {
        viewModel = DiaryListViewModel(repository: repository, session: session, trash: trash,
                                       calendar: calendar, now: now)
        self.imageLoader = imageLoader
    }
}
