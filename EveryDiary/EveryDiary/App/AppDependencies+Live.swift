import FirebaseAuth
import FirebaseFirestore
import Foundation

extension AppDependencies {
    static func live() -> AppDependencies {
        AppDependencies(
            diaryRepository: FirebaseDiaryReadingRepository(database: .firestore()),
            userSession: FirebaseDiaryUserSession(auth: .auth()),
            calendarImageLoader: CachedCalendarImageLoader(cache: .shared),
            calendar: .current,
            now: Date.init
        )
    }
}
