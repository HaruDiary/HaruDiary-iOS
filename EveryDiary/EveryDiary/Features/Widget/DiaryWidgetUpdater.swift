import Foundation

/// Keeps the home screen widget's snapshot up to date with the signed-in user's diaries.
/// After a sign-out or an account switch the previous user's days are cleared at once.
@MainActor
final class DiaryWidgetUpdater {
    private let feed: UserDiaryFeed
    private let store: any DiaryWidgetSnapshotStoring
    private let calendar: Calendar
    private let now: () -> Date
    private let reloadWidgets: () -> Void

    init(feed: UserDiaryFeed, store: any DiaryWidgetSnapshotStoring, calendar: Calendar, now: @escaping () -> Date,
         reloadWidgets: @escaping () -> Void) {
        self.feed = feed
        self.store = store
        self.calendar = calendar
        self.now = now
        self.reloadWidgets = reloadWidgets
        feed.onEvent = { [weak self] in self?.apply($0) }
    }

    func start() {
        feed.start()
    }

    func stop() {
        feed.stop()
    }

    private func apply(_ event: UserDiaryFeed.Event) {
        switch event {
        case .userChanged:
            // Days kept for the same user (from the last run) stay until the diaries are known again;
            // anyone else's go at once, before a single diary of the new account has arrived.
            let userID = feed.currentUserID
            if userID == nil || store.load().userID != userID { publish(.empty) }
        case .received(let entries):
            publish(DiaryWidgetSnapshot(entries: entries, userID: feed.currentUserID, calendar: calendar, today: now()))
        case .loading, .failed:
            // What the widget shows stays until the diaries are known again.
            break
        }
    }

    /// The widget is redrawn only when its days changed: reloads are limited by the system.
    private func publish(_ snapshot: DiaryWidgetSnapshot) {
        guard snapshot != store.load() else { return }
        store.save(snapshot)
        reloadWidgets()
    }
}
