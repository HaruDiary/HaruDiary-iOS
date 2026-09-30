import Foundation

@MainActor
struct AppDependencies {
    let diaryRepository: any DiaryReadingRepository
    let userSession: any DiaryUserSession
    let accountSession: any AccountSession
    let signInGateway: any SocialSignInGateway
    let diaryTrash: any DiaryTrashing
    let calendarImageLoader: any CalendarImageLoading
    let calendar: Calendar
    let now: () -> Date
    /// The app-wide writing reminders, shared with the reminder settings screen so their reschedules run in order.
    /// Created by the scene (it starts a diary subscription); nil where no scene set it up.
    var reminders: DiaryReminders? = nil

    func makeCalendarModule() -> CalendarModule {
        CalendarModule(repository: diaryRepository, session: userSession,
                       imageLoader: calendarImageLoader, calendar: calendar, now: now)
    }

    func makeJourneyModule() -> JourneyModule {
        JourneyModule(repository: diaryRepository, session: userSession, calendar: calendar, now: now)
    }

    func makeTrashModule() -> TrashModule {
        TrashModule(repository: diaryRepository, session: userSession, trash: diaryTrash,
                    imageLoader: calendarImageLoader, calendar: calendar, now: now)
    }

    func makeSettingsModule() -> SettingsModule {
        SettingsModule(session: accountSession, signInGateway: signInGateway, makeTrashModule: makeTrashModule,
                       reminders: reminders)
    }

    func makeDiaryListModule() -> DiaryListModule {
        DiaryListModule(repository: diaryRepository, session: userSession, trash: diaryTrash,
                        imageLoader: calendarImageLoader, calendar: calendar, now: now)
    }
}
