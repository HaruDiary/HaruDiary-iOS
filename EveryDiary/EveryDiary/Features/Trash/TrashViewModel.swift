import Foundation
import Observation

@MainActor
@Observable
final class TrashViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    enum Action: Equatable {
        case restore
        case delete
    }

    enum Notice: Equatable {
        case completed(Action, count: Int)
        /// `succeeded` diaries were handled before the others failed.
        case failed(Action, succeeded: Int, failed: Int)
    }

    private(set) var state: LoadState = .idle
    private(set) var sections: [DiaryListSection] = []
    private(set) var trashedCount = 0
    private(set) var isPerformingBulkAction = false
    /// A one-time message for the screen to show and then clear.
    var notice: Notice?
    var query = "" {
        didSet { rebuildSections() }
    }
    let calendar: Calendar

    @ObservationIgnored private let feed: UserDiaryFeed
    @ObservationIgnored private let trash: any DiaryTrashing
    @ObservationIgnored private let purger: ExpiredTrashPurger
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var entries: [DiaryEntry] = []
    @ObservationIgnored private var workingIDs: Set<String> = []
    @ObservationIgnored private var userGeneration = 0

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, trash: any DiaryTrashing,
         calendar: Calendar, now: @escaping () -> Date = Date.init) {
        feed = UserDiaryFeed(repository: repository, session: session)
        self.trash = trash
        purger = ExpiredTrashPurger(trash: trash, calendar: calendar)
        self.calendar = calendar
        self.now = now
        feed.onEvent = { [weak self] in self?.apply($0) }
    }

    var isSearching: Bool {
        !DiaryListIndex.normalizedQuery(query).isEmpty
    }

    var visibleCount: Int {
        sections.reduce(0) { $0 + $1.entries.count }
    }

    func start() {
        feed.start()
    }

    func stop() {
        feed.stop()
    }

    func retry() {
        feed.retry()
    }

    func daysRemaining(for entry: DiaryEntry) -> Int? {
        DiaryTrashPolicy.daysRemaining(for: entry, now: now(), calendar: calendar)
    }

    func restore(_ entry: DiaryEntry) async {
        await perform(.restore, on: [entry])
    }

    func deletePermanently(_ entry: DiaryEntry) async {
        await perform(.delete, on: [entry])
    }

    /// Acts on every diary in the trash, not only the ones matching the current search.
    func restoreAll() async {
        await performBulk(.restore)
    }

    func emptyTrash() async {
        await performBulk(.delete)
    }

    private func performBulk(_ action: Action) async {
        guard !isPerformingBulkAction else { return }
        isPerformingBulkAction = true
        await perform(action, on: trashedEntries)
        isPerformingBulkAction = false
    }

    // Requests are bound to the user whose trash is shown; results for a previous user are dropped.
    private func perform(_ action: Action, on targets: [DiaryEntry]) async {
        guard let userID = feed.currentUserID else {
            notice = .failed(action, succeeded: 0, failed: max(targets.count, 1))
            return
        }
        let targets = targets.filter { entry in
            guard let id = entry.id else { return false }
            return !workingIDs.contains(id)
        }
        guard !targets.isEmpty else { return }
        let generation = userGeneration
        let ids = targets.compactMap(\.id)
        workingIDs.formUnion(ids)
        var succeeded = 0
        var failed = 0
        for entry in targets {
            guard let id = entry.id else { continue }
            do {
                switch action {
                case .restore:
                    try await trash.restore(diaryID: id, userID: userID)
                case .delete:
                    try await trash.deletePermanently(diaryID: id, userID: userID, imageURLs: entry.imageURL ?? [])
                }
                succeeded += 1
            } catch {
                failed += 1
            }
        }
        guard generation == userGeneration else { return }
        workingIDs.subtract(ids)
        notice = failed == 0 ? .completed(action, count: succeeded) : .failed(action, succeeded: succeeded, failed: failed)
    }

    private var trashedEntries: [DiaryEntry] {
        DiaryListIndex.sections(from: visibleEntries, calendar: calendar, scope: .trash).flatMap(\.entries)
    }

    // Diaries past their deadline are being purged and are no longer shown.
    private var visibleEntries: [DiaryEntry] {
        let current = now()
        return entries.filter { !DiaryTrashPolicy.isExpired($0, now: current, calendar: calendar) }
    }

    private func apply(_ event: UserDiaryFeed.Event) {
        switch event {
        case .userChanged:
            userGeneration += 1
            workingIDs.removeAll()
            entries = []
            rebuildSections()
        case .loading:
            state = .loading
        case .received(let snapshot):
            entries = snapshot
            rebuildSections()
            state = .loaded
            purgeExpired(in: snapshot)
        case .failed:
            state = .failed
        }
    }

    private func purgeExpired(in snapshot: [DiaryEntry]) {
        guard let userID = feed.currentUserID else { return }
        let current = now()
        Task { [purger] in
            let result = await purger.purgeExpired(in: snapshot, userID: userID, now: current)
            if result.deletedCount + result.failedCount > 0 {
                // Counts only: which diaries were removed stays out of the log.
                print("Expired trash purge: \(result.deletedCount) deleted, \(result.failedCount) failed")
            }
        }
    }

    private func rebuildSections() {
        let visible = visibleEntries
        sections = DiaryListIndex.sections(from: visible, matching: query, calendar: calendar, scope: .trash)
        trashedCount = DiaryListIndex.sections(from: visible, calendar: calendar, scope: .trash).reduce(0) { $0 + $1.entries.count }
    }
}
