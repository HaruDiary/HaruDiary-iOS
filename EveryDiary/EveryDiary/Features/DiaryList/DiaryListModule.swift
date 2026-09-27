import FirebaseAuth
import FirebaseFirestore
import UIKit

@MainActor
enum DiaryListModule {
    static func makeViewModel() -> DiaryListViewModel {
        DiaryListViewModel(
            repository: FirebaseDiaryReadingRepository(database: .firestore()),
            session: FirebaseDiaryUserSession(auth: .auth()),
            updater: FirebaseDiaryUpdater(manager: .shared),
            calendar: .current
        )
    }

    static func makeViewController() -> UIViewController {
        DiaryListHostingController(viewModel: makeViewModel(), imageLoader: CachedCalendarImageLoader(cache: .shared))
    }
}
