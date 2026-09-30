import SwiftUI
import UIKit

@MainActor
enum ReminderModule {
    static func makeReminders(calendar: Calendar = .current) -> DiaryReminders {
        DiaryReminders(store: UserDefaultsReminderStore(calendar: calendar), scheduler: UserNotificationReminderScheduler(),
                       calendar: calendar, now: Date.init)
    }

    static func makeSettingsViewController() -> UIViewController {
        let calendar = Calendar.current
        let model = ReminderSettingsViewModel(reminders: makeReminders(calendar: calendar), calendar: calendar, now: Date.init)
        return ReminderSettingsHostingController(viewModel: model)
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

// Remove this UIKit bridge when settings move to SwiftUI.
@MainActor
final class ReminderSettingsHostingController: UIHostingController<ReminderSettingsView> {
    init(viewModel: ReminderSettingsViewModel) {
        super.init(rootView: ReminderSettingsView(viewModel: viewModel))
        title = "알림"
    }

    required init?(coder: NSCoder) { return nil }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DiaryTheme.Colors.brandUIKit
    }
}
