import Foundation

@MainActor
struct DiaryListModule {
    let viewModel: DiaryListViewModel
    let imageLoader: any CalendarImageLoading

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, updater: any DiaryUpdating,
         imageLoader: any CalendarImageLoading, calendar: Calendar, now: @escaping () -> Date) {
        viewModel = DiaryListViewModel(repository: repository, session: session, updater: updater,
                                       calendar: calendar, now: now)
        self.imageLoader = imageLoader
    }
}
