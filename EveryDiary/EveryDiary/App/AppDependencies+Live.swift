import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

extension AppDependencies {
    static func live() -> AppDependencies {
        let appleRecords = AppleSignInRecords(secrets: AppleSignInSecrets(secrets: KeychainSecretStore(), legacy: .standard))
        return AppDependencies(
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
            calendarImageLoader: CachedCalendarImageLoader(cache: .shared),
            calendar: .current,
            now: Date.init
        )
    }
}
