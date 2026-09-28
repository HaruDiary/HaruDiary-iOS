import Foundation

@MainActor
struct SettingsModule {
    let viewModel: SettingsViewModel
    let signInGateway: any SocialSignInGateway
    let makeTrashModule: () -> TrashModule

    init(session: any AccountSession, signInGateway: any SocialSignInGateway, makeTrashModule: @escaping () -> TrashModule) {
        viewModel = SettingsViewModel(session: session)
        self.signInGateway = signInGateway
        self.makeTrashModule = makeTrashModule
    }
}
