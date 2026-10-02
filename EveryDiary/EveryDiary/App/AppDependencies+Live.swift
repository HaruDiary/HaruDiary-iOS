import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

extension AppDependencies {
    static func live() -> AppDependencies {
        let appleRecords = AppleSignInRecords(secrets: AppleSignInSecrets(secrets: KeychainSecretStore(), legacy: .standard))
        var dependencies = AppDependencies(
            diaryRepository: FirebaseDiaryReadingRepository(database: .firestore()),
            userSession: FirebaseDiaryUserSession(auth: .auth()),
            accountSession: FirebaseAccountSession(
                auth: .auth(),
                dataEraser: FirebaseUserDataEraser(database: .firestore(), storage: .storage()),
                storage: .storage(),
                appleRecords: appleRecords
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
        dependencies.userDirectory = FirebaseUserDirectory(database: .firestore())
        dependencies.diaryDrafts = UserDefaultsDiaryDraftStore()
        dependencies.profilePhotos = ProfilePhotoLoader(files: .inCaches())
        return dependencies
    }
}
