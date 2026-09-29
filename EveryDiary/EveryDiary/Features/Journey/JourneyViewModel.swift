import Foundation
import Observation

/// State of the journey tab and its honor screen. Both screens share this model, so one diary
/// subscription serves them; it follows the signed-in user and ends with `stop()`.
@MainActor
@Observable
final class JourneyViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private(set) var state: LoadState = .idle
    private(set) var record: JourneyRecord = .empty
    let calendar: Calendar

    @ObservationIgnored private let feed: UserDiaryFeed
    @ObservationIgnored private let now: () -> Date

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, calendar: Calendar, now: @escaping () -> Date = Date.init) {
        feed = UserDiaryFeed(repository: repository, session: session)
        self.calendar = calendar
        self.now = now
        feed.onEvent = { [weak self] in self?.apply($0) }
    }

    /// Read again when the screen appears, so the month moves on while the app stays open.
    var currentMonth: JourneyMonth {
        record.month(containing: now(), calendar: calendar)
    }

    var numberOfDaysInCurrentMonth: Int {
        calendar.range(of: .day, in: .month, for: now())?.count ?? 0
    }

    /// Years in the collection: every year with a diary and the current year, newest first.
    var years: [Int] {
        Set(record.months.map(\.year) + [calendar.component(.year, from: now())]).sorted(by: >)
    }

    func month(year: Int, month: Int) -> JourneyMonth {
        record.month(year: year, month: month)
    }

    func progress(ofYear year: Int) -> JourneyYearProgress {
        record.progress(ofYear: year)
    }

    func numberOfDays(year: Int, month: Int) -> Int {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 0 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 0
    }

    /// A month that has not started yet; its picture is kept hidden.
    func isUpcoming(year: Int, month: Int) -> Bool {
        let today = now()
        let currentYear = calendar.component(.year, from: today)
        return (year, month) > (currentYear, calendar.component(.month, from: today))
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

    private func apply(_ event: UserDiaryFeed.Event) {
        switch event {
        case .userChanged:
            record = .empty
        case .loading:
            state = .loading
        case .received(let entries):
            record = JourneyRecord(entries: entries, calendar: calendar)
            state = .loaded
        case .failed:
            state = .failed
        }
    }
}
