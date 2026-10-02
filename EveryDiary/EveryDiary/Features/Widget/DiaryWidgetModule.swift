import Foundation
import WidgetKit

extension AppDependencies {
    /// Follows the signed-in user's diaries for as long as the app runs and tells the widget when its days change.
    func makeDiaryWidgetUpdater() -> DiaryWidgetUpdater {
        DiaryWidgetUpdater(feed: UserDiaryFeed(repository: diaryRepository, session: userSession),
                           store: UserDefaultsDiaryWidgetStore(), calendar: calendar, now: now,
                           reloadWidgets: { WidgetCenter.shared.reloadTimelines(ofKind: DiaryWidgetShared.widgetKind) })
    }
}
