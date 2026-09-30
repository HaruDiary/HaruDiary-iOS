import Foundation

@MainActor
struct SettingsModule {
    let viewModel: SettingsViewModel
    let signInGateway: any SocialSignInGateway
    let makeTrashModule: () -> TrashModule
    let reminders: DiaryReminders?

    init(session: any AccountSession, signInGateway: any SocialSignInGateway, makeTrashModule: @escaping () -> TrashModule,
         reminders: DiaryReminders? = nil) {
        viewModel = SettingsViewModel(session: session)
        self.signInGateway = signInGateway
        self.makeTrashModule = makeTrashModule
        self.reminders = reminders
    }
}
