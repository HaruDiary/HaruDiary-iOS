import Foundation

@MainActor
struct AppDependencies {
    let diaryRepository: any DiaryReadingRepository
    let userSession: any DiaryUserSession
    let accountSession: any AccountSession
    let signInGateway: any SocialSignInGateway
    let diaryTrash: any DiaryTrashing
    let diarySaving: any DiarySaving
    let calendarImageLoader: any CalendarImageLoading
    let calendar: Calendar
    let now: () -> Date

    func makeCalendarModule() -> CalendarModule {
        CalendarModule(repository: diaryRepository, session: userSession,
                       imageLoader: calendarImageLoader, calendar: calendar, now: now)
    }

    func makeTrashModule() -> TrashModule {
        TrashModule(repository: diaryRepository, session: userSession, trash: diaryTrash,
                    imageLoader: calendarImageLoader, calendar: calendar, now: now)
    }

    func makeSettingsModule() -> SettingsModule {
        SettingsModule(session: accountSession, signInGateway: signInGateway, makeTrashModule: makeTrashModule)
    }

    func makeDiaryListModule() -> DiaryListModule {
        DiaryListModule(repository: diaryRepository, session: userSession, trash: diaryTrash,
                        imageLoader: calendarImageLoader, calendar: calendar, now: now)
    }
}
