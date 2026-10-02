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
    /// The app-wide writing reminders, shared with the reminder settings screen so their reschedules run in order.
    /// Created by the scene (it starts a diary subscription); nil where no scene set it up.
    var reminders: DiaryReminders? = nil
    /// The app's text size, applied to its windows by the scene and changed from settings.
    var textSize: AppTextSizeController? = nil
    /// Light or dark, applied to the app's windows by the scene and changed from settings.
    var appearance: AppAppearanceController? = nil
    /// Describes the signed-in account in `users/{userID}` so accounts can be told apart; nil where nothing is written.
    var userDirectory: (any UserDirectoryWriting)? = nil
    /// Unsaved writing kept on the device; one store for every editor.
    var diaryDrafts: (any DiaryDraftStoring)? = nil
    /// The profile photo kept on the device; shared, so every settings screen shows it without loading.
    var profilePhotos: ProfilePhotoLoader? = nil

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
                       reminders: reminders, textSize: textSize, appearance: appearance, profilePhotos: profilePhotos,
                       diaryDrafts: diaryDrafts)
    }

    func makeDiaryExportViewModel() -> DiaryExportViewModel {
        DiaryExportViewModel(repository: diaryRepository, session: userSession, calendar: calendar, now: now)
    }

    /// Nil where no photo is kept on the device.
    func makeProfilePhotoKeeper() -> ProfilePhotoKeeper? {
        profilePhotos.map { ProfilePhotoKeeper(session: accountSession, photos: $0) }
    }

    func makeDiaryListModule() -> DiaryListModule {
        DiaryListModule(repository: diaryRepository, session: userSession, trash: diaryTrash,
                        imageLoader: calendarImageLoader, calendar: calendar, now: now)
    }
}
