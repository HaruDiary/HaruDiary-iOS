import Foundation

@MainActor
struct SettingsModule {
    let viewModel: SettingsViewModel
    let signInGateway: any SocialSignInGateway
    let makeTrashModule: () -> TrashModule
    let reminders: DiaryReminders?
    let textSize: AppTextSizeController?
    let appearance: AppAppearanceController?
    let profilePhotos: ProfilePhotoLoader?

    init(session: any AccountSession, signInGateway: any SocialSignInGateway, makeTrashModule: @escaping () -> TrashModule,
         reminders: DiaryReminders? = nil, textSize: AppTextSizeController? = nil, appearance: AppAppearanceController? = nil,
         profilePhotos: ProfilePhotoLoader? = nil, diaryDrafts: (any DiaryDraftStoring)? = nil) {
        viewModel = SettingsViewModel(session: session, photos: profilePhotos, drafts: diaryDrafts)
        self.profilePhotos = profilePhotos
        self.signInGateway = signInGateway
        self.makeTrashModule = makeTrashModule
        self.reminders = reminders
        self.textSize = textSize
        self.appearance = appearance
    }
}
