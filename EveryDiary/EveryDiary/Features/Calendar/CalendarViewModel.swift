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

    @ObservationIgnored private let feed: UserDiaryFeed
    @ObservationIgnored private let now: () -> Date

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, calendar: Calendar, now: @escaping () -> Date = Date.init) {
        feed = UserDiaryFeed(repository: repository, session: session)
        self.calendar = calendar
        self.now = now
        let today = now()
        displayedMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
        selectedDate = calendar.startOfDay(for: today)
        index = CalendarDiaryIndex(entries: [], calendar: calendar, now: today)
        feed.onEvent = { [weak self] in self?.apply($0) }
    }

    var selectedDay: CalendarDay {
        CalendarDay(date: selectedDate, calendar: calendar)
    }

    /// Read from the clock each time, so the marker moves on while the app stays open.
    var today: CalendarDay {
        CalendarDay(date: now(), calendar: calendar)
    }

    static let minimumYear = 2011

    /// The months of `year` that have a diary, for the year overview.
    func monthsWithDiaries(in year: Int) -> Set<Int> {
        Set(index.decoratedDays.lazy.filter { $0.year == year }.map(\.month))
    }

    var selectedEntries: [DiaryEntry] {
        index.entries(on: selectedDay)
    }

    var month: CalendarMonth? {
        CalendarMonth(date: displayedMonth, calendar: calendar)
    }

    var canMoveToPreviousMonth: Bool {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return false }
        return calendar.component(.year, from: previous) >= Self.minimumYear
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

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        displayedMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    /// Jumps to a month picked in the year overview. Today is selected in the current month, otherwise the 1st.
    func showMonth(year: Int, month: Int) {
        guard year >= Self.minimumYear, (1...12).contains(month),
              let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return }
        let now = now()
        if calendar.isDate(now, equalTo: start, toGranularity: .month) {
            select(now)
        } else {
            select(start)
        }
    }

    func showToday() {
        select(now())
    }

    func moveMonth(by offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: displayedMonth),
              calendar.component(.year, from: next) >= Self.minimumYear else { return }
        displayedMonth = next
        selectedDate = calendar.startOfDay(for: next)
    }

    private func apply(_ event: UserDiaryFeed.Event) {
        switch event {
        case .userChanged(let isDifferentUser):
            index = CalendarDiaryIndex(entries: [], calendar: calendar, now: now())
            if isDifferentUser {
                select(now())
            }
        case .loading:
            state = .loading
        case .received(let entries):
            index = CalendarDiaryIndex(entries: entries, calendar: calendar, now: now())
            state = .loaded
        case .failed:
            state = .failed
        }
    }
}
