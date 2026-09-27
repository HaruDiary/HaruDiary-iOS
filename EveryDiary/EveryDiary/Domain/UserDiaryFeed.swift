import Foundation

/// Follows the signed-in user and keeps exactly one diary subscription for that user.
/// Late results from a cancelled subscription or a previous user are never delivered.
@MainActor
final class UserDiaryFeed {
    enum Event {
        /// The observed user changed; drop entries that belonged to the previous state.
        case userChanged(isDifferentUser: Bool)
        case loading
        case received([DiaryEntry])
        case failed
    }

    var onEvent: ((Event) -> Void)?

    private let repository: any DiaryReadingRepository
    private let session: any DiaryUserSession
    private var sessionTask: Task<Void, Never>?
    private var diaryTask: Task<Void, Never>?
    private var userID: String?
    private var hasReceivedUser = false
    private var generation = 0

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession) {
        self.repository = repository
        self.session = session
    }

    deinit {
        sessionTask?.cancel()
        diaryTask?.cancel()
    }

    func start() {
        guard sessionTask == nil else { return }
        let users = session.observeUserIDs()
        sessionTask = Task { [weak self] in
            for await userID in users {
                guard !Task.isCancelled else { return }
                self?.userDidChange(userID)
            }
        }
    }

    func stop() {
        generation += 1
        sessionTask?.cancel()
        diaryTask?.cancel()
        sessionTask = nil
        diaryTask = nil
        hasReceivedUser = false
    }

    func retry() {
        observeDiaries()
    }

    private func userDidChange(_ newUserID: String?) {
        guard !hasReceivedUser || userID != newUserID else { return }
        let isDifferentUser = userID != newUserID
        userID = newUserID
        hasReceivedUser = true
        onEvent?(.userChanged(isDifferentUser: isDifferentUser))
        observeDiaries()
    }

    private func observeDiaries() {
        generation += 1
        diaryTask?.cancel()
        diaryTask = nil
        guard let userID else {
            onEvent?(.received([]))
            return
        }
        onEvent?(.loading)
        let observationGeneration = generation
        let entries = repository.observeDiaries(userID: userID)
        diaryTask = Task { [weak self] in
            do {
                for try await snapshot in entries {
                    guard !Task.isCancelled else { return }
                    self?.deliver(.received(snapshot), generation: observationGeneration)
                }
                // A live subscription should not end on its own; treat it like a failure so the UI can retry.
                if !Task.isCancelled {
                    self?.deliver(.failed, generation: observationGeneration)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.deliver(.failed, generation: observationGeneration)
            }
        }
    }

    private func deliver(_ event: Event, generation: Int) {
        guard generation == self.generation else { return }
        onEvent?(event)
    }
}
