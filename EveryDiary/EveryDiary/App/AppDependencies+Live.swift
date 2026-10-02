import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

extension AppDependencies {
    static func live() -> AppDependencies {
        let appleRecords = AppleSignInRecords(secrets: AppleSignInSecrets(secrets: KeychainSecretStore(), legacy: .standard))
        // One directory for the updater and the withdrawal, so a withdrawal can stop the account's entry being written.
        let userDirectory = SuspendableUserDirectory(FirebaseUserDirectory(database: .firestore()))
        var dependencies = AppDependencies(
            diaryRepository: FirebaseDiaryReadingRepository(database: .firestore()),
            userSession: FirebaseDiaryUserSession(auth: .auth()),
            accountSession: FirebaseAccountSession(
                auth: .auth(),
                dataEraser: FirebaseUserDataEraser(database: .firestore(), storage: .storage(), directory: userDirectory),
                storage: .storage(),
                appleRecords: appleRecords,
                directory: userDirectory
            ),
            signInGateway: FirebaseSocialSignInGateway(auth: .auth(), appleRecords: appleRecords),
            diaryTrash: FirebaseDiaryTrash(database: .firestore()),
            diarySaving: DiarySaveCoordinator(
                authentication: LiveDiarySaveAuthentication(),
                images: LiveDiaryImageStore(),
                entries: LiveDiaryEntryWriter()
            ),
            calendarImageLoader: CachedCalendarImageLoader(cache: .shared),
            calendar: .current,
            now: Date.init
        )
        dependencies.userDirectory = userDirectory
        dependencies.diaryDrafts = UserDefaultsDiaryDraftStore()
        dependencies.profilePhotos = ProfilePhotoLoader(files: .inCaches())
        return dependencies
    }
}
