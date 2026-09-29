import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

extension AppDependencies {
    static func live() -> AppDependencies {
        AppDependencies(
            diaryRepository: FirebaseDiaryReadingRepository(database: .firestore()),
            userSession: FirebaseDiaryUserSession(auth: .auth()),
            accountSession: FirebaseAccountSession(
                auth: .auth(),
                dataEraser: FirebaseUserDataEraser(database: .firestore(), storage: .storage())
            ),
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
    }
}
