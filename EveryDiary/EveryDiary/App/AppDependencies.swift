import Foundation

@MainActor
struct AppDependencies {
    let diaryRepository: any DiaryReadingRepository
    let userSession: any DiaryUserSession
    let calendarImageLoader: any CalendarImageLoading
    let calendar: Calendar
    let now: () -> Date

    func makeCalendarModule() -> CalendarModule {
        CalendarModule(repository: diaryRepository, session: userSession,
                       imageLoader: calendarImageLoader, calendar: calendar, now: now)
    }
}
