import Foundation

@MainActor
struct CalendarModule {
    let viewModel: CalendarViewModel
    let imageLoader: any CalendarImageLoading

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession,
         imageLoader: any CalendarImageLoading, calendar: Calendar, now: @escaping () -> Date) {
        viewModel = CalendarViewModel(repository: repository, session: session, calendar: calendar, now: now)
        self.imageLoader = imageLoader
    }
}
