import Foundation

@MainActor
struct JourneyModule {
    let viewModel: JourneyViewModel

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, calendar: Calendar, now: @escaping () -> Date) {
        viewModel = JourneyViewModel(repository: repository, session: session, calendar: calendar, now: now)
    }
}
