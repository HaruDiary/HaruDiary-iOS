import Foundation

@MainActor
struct SettingsModule {
    let viewModel: SettingsViewModel
    let makeTrashModule: () -> TrashModule

    init(session: any AccountSession, makeTrashModule: @escaping () -> TrashModule) {
        viewModel = SettingsViewModel(session: session)
        self.makeTrashModule = makeTrashModule
    }
}
