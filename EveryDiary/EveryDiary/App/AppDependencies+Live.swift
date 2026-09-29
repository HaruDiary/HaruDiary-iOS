import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

extension AppDependencies {
    static func live() -> AppDependencies {
        let appleTokens = AppleTokenRevocation(store: AppleRefreshTokenStore(secrets: KeychainSecretStore(), legacy: .standard))
        return AppDependencies(
            diaryRepository: FirebaseDiaryReadingRepository(database: .firestore()),
            userSession: FirebaseDiaryUserSession(auth: .auth()),
            accountSession: FirebaseAccountSession(
                auth: .auth(),
                dataEraser: FirebaseUserDataEraser(database: .firestore(), storage: .storage()),
                storage: .storage(),
                appleTokens: appleTokens
            ),
            signInGateway: FirebaseSocialSignInGateway(auth: .auth(), appleTokens: appleTokens),
            diaryTrash: FirebaseDiaryTrash(database: .firestore()),
            calendarImageLoader: CachedCalendarImageLoader(cache: .shared),
            calendar: .current,
            now: Date.init
        )
    }
}
