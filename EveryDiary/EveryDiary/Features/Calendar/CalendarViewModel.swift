import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private(set) var state: LoadState = .idle
    private(set) var index: CalendarDiaryIndex
    private(set) var displayedMonth: Date
    private(set) var selectedDate: Date
    let calendar: Calendar

    @ObservationIgnored private let repository: any DiaryReadingRepository
    @ObservationIgnored private let session: any DiaryUserSession
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var sessionTask: Task<Void, Never>?
    @ObservationIgnored private var diaryTask: Task<Void, Never>?
    @ObservationIgnored private var userID: String?
    @ObservationIgnored private var hasReceivedUser = false
    @ObservationIgnored private var generation = 0

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, calendar: Calendar, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.session = session
        self.calendar = calendar
        self.now = now
        let today = now()
        displayedMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        selectedDate = calendar.startOfDay(for: today)
        index = CalendarDiaryIndex(entries: [], calendar: calendar, now: today)
    }

    deinit {
        sessionTask?.cancel()
        diaryTask?.cancel()
    }

    var selectedDay: CalendarDay {
        CalendarDay(date: selectedDate, calendar: calendar)
    }

    var selectedEntries: [DiaryEntry] {
        index.entries(on: selectedDay)
    }

    var month: CalendarMonth? {
        CalendarMonth(date: displayedMonth, calendar: calendar)
    }

    var canMoveToPreviousMonth: Bool {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return false }
        return calendar.component(.year, from: previous) >= 2011
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

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        displayedMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    func moveMonth(by offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: displayedMonth),
              calendar.component(.year, from: next) >= 2011 else { return }
        displayedMonth = next
        selectedDate = calendar.startOfDay(for: next)
    }

    private func userDidChange(_ newUserID: String?) {
        guard !hasReceivedUser || userID != newUserID else { return }
        let isDifferentUser = userID != newUserID
        userID = newUserID
        hasReceivedUser = true
        index = CalendarDiaryIndex(entries: [], calendar: calendar, now: now())
        if isDifferentUser {
            select(now())
        }
        observeDiaries()
    }

    private func observeDiaries() {
        generation += 1
        diaryTask?.cancel()
        diaryTask = nil
        guard let userID else {
            index = CalendarDiaryIndex(entries: [], calendar: calendar, now: now())
            state = .loaded
            return
        }
        state = .loading
        let observationGeneration = generation
        let entries = repository.observeDiaries(userID: userID)
        diaryTask = Task { [weak self] in
            do {
                for try await snapshot in entries {
                    guard !Task.isCancelled else { return }
                    self?.receive(snapshot, generation: observationGeneration)
                }
                if !Task.isCancelled {
                    self?.receiveFailure(generation: observationGeneration)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.receiveFailure(generation: observationGeneration)
            }
        }
    }

    private func receive(_ entries: [DiaryEntry], generation: Int) {
        guard generation == self.generation else { return }
        index = CalendarDiaryIndex(entries: entries, calendar: calendar, now: now())
        state = .loaded
    }

    private func receiveFailure(generation: Int) {
        guard generation == self.generation else { return }
        state = .failed
    }
}
