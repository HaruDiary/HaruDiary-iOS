import Foundation

@MainActor
enum ReminderModule {
    static func makeReminders(calendar: Calendar = .current) -> DiaryReminders {
        DiaryReminders(store: UserDefaultsReminderStore(calendar: calendar), scheduler: UserNotificationReminderScheduler(),
                       calendar: calendar, now: Date.init)
    }

    /// `reminders` is the app-wide instance; a separate one would reschedule concurrently with it.
    static func makeSettingsViewModel(reminders: DiaryReminders?) -> ReminderSettingsViewModel {
        let calendar = Calendar.current
        return ReminderSettingsViewModel(reminders: reminders ?? makeReminders(calendar: calendar), calendar: calendar,
                                         now: Date.init)
    }
}

extension AppDependencies {
    /// The app-wide reminders, following the signed-in user's diaries to skip a day once it is written.
    func makeDiaryReminders() -> DiaryReminders {
        let reminders = ReminderModule.makeReminders(calendar: calendar)
        reminders.watch(UserDiaryFeed(repository: diaryRepository, session: userSession))
        return reminders
    }
}
