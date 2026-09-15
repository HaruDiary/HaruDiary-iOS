import FirebaseAuth
import FirebaseFirestore
import UIKit

@MainActor
enum CalendarModule {
    static func makeViewController() -> UIViewController {
        let viewModel = CalendarViewModel(
            repository: FirebaseDiaryReadingRepository(database: .firestore()),
            session: FirebaseDiaryUserSession(auth: .auth()),
            calendar: .current
        )
        return CalendarHostingController(viewModel: viewModel, imageLoader: CachedCalendarImageLoader(cache: .shared))
    }
}
