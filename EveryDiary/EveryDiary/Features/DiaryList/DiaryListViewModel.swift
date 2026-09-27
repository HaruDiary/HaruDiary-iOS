import Foundation
import Observation

@MainActor
@Observable
final class DiaryListViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    enum Notice: Equatable {
        case movedToTrash
        case trashFailed
    }

    private(set) var state: LoadState = .idle
    private(set) var sections: [DiaryListSection] = []
    private(set) var isUploadingDiary = false
    /// A one-time message for the screen to show and then clear.
    var notice: Notice?
    var query = "" {
        didSet { rebuildSections() }
    }
    let calendar: Calendar

    @ObservationIgnored private let feed: UserDiaryFeed
    @ObservationIgnored private let trash: any DiaryTrashing
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var entries: [DiaryEntry] = []
    @ObservationIgnored private var pendingUploadCount = 0
    @ObservationIgnored private var trashingIDs: Set<String> = []
    @ObservationIgnored private var userGeneration = 0

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, trash: any DiaryTrashing,
         calendar: Calendar, now: @escaping () -> Date = Date.init) {
        feed = UserDiaryFeed(repository: repository, session: session)
        self.trash = trash
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

    // The editor reports one start and one finish per save; overlapping saves keep the indicator visible.
    func uploadDidStart() {
        pendingUploadCount += 1
        isUploadingDiary = true
    }

    func uploadDidFinish() {
        pendingUploadCount = max(0, pendingUploadCount - 1)
        isUploadingDiary = pendingUploadCount > 0
    }

    func moveToTrash(_ entry: DiaryEntry) async {
        // Bind the request to the user whose list is shown, not to whoever is signed in when it is written.
        guard let diaryID = entry.id, let userID = feed.currentUserID else {
            notice = .trashFailed
            return
        }
        guard !trashingIDs.contains(diaryID) else { return }
        let generation = userGeneration
        trashingIDs.insert(diaryID)
        let result: Notice
        do {
            // The live subscription removes the diary from the list once the change is stored.
            try await trash.moveToTrash(diaryID: diaryID, userID: userID, at: now())
            result = .movedToTrash
        } catch {
            result = .trashFailed
        }
        // A late result for the previous user must not appear on the next user's screen.
        guard generation == userGeneration else { return }
        trashingIDs.remove(diaryID)
        notice = result
    }

    private func apply(_ event: UserDiaryFeed.Event) {
        switch event {
        case .userChanged:
            userGeneration += 1
            trashingIDs.removeAll()
            entries = []
            rebuildSections()
        case .loading:
            state = .loading
        case .received(let snapshot):
            entries = snapshot
            rebuildSections()
            state = .loaded
        case .failed:
            state = .failed
        }
    }

    private func rebuildSections() {
        sections = DiaryListIndex.sections(from: entries, matching: query, calendar: calendar)
    }
}
