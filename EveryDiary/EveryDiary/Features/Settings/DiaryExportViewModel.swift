import Foundation
import Observation

/// Gathers the signed-in user's diaries once and writes them into one text file to share.
@MainActor
@Observable
final class DiaryExportViewModel {
    enum State: Equatable {
        case loading
        /// No diary to put in a file.
        case empty
        case ready(file: URL, diaryCount: Int)
        case failed
    }

    private(set) var state: State = .loading

    @ObservationIgnored private let feed: UserDiaryFeed
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let write: (_ text: String, _ fileName: String) throws -> URL
    @ObservationIgnored private let remove: (URL) -> Void

    init(repository: any DiaryReadingRepository, session: any DiaryUserSession, calendar: Calendar, now: @escaping () -> Date,
         write: @escaping (_ text: String, _ fileName: String) throws -> URL = DiaryExportViewModel.writeTemporaryFile,
         remove: @escaping (URL) -> Void = { try? FileManager.default.removeItem(at: $0) }) {
        feed = UserDiaryFeed(repository: repository, session: session)
        self.calendar = calendar
        self.now = now
        self.write = write
        self.remove = remove
        feed.onEvent = { [weak self] in self?.apply($0) }
    }

    func start() {
        feed.start()
    }

    /// Leaving the screen ends the subscription and removes the file: diaries are not left lying in a temporary folder.
    func stop() {
        feed.stop()
        removeFile()
        state = .loading
    }

    func retry() {
        feed.retry()
    }

    private func apply(_ event: UserDiaryFeed.Event) {
        switch event {
        case .userChanged:
            // The file made for the previous user is not offered to the next one.
            removeFile()
            state = .loading
        case .loading:
            if case .ready = state { return }
            state = .loading
        case .received(let entries):
            removeFile()
            let count = DiaryExport.exportable(entries).count
            guard count > 0 else {
                state = .empty
                return
            }
            let exportedAt = now()
            do {
                let file = try write(DiaryExport.text(from: entries, exportedAt: exportedAt, calendar: calendar),
                                     DiaryExport.fileName(exportedAt: exportedAt, calendar: calendar))
                state = .ready(file: file, diaryCount: count)
            } catch {
                state = .failed
            }
        case .failed:
            if case .ready = state { return }
            state = .failed
        }
    }

    private func removeFile() {
        if case .ready(let file, _) = state { remove(file) }
    }

    /// In its own folder, so the file keeps its readable name.
    nonisolated static func writeTemporaryFile(_ text: String, _ fileName: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("DiaryExport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(fileName)
        try Data(text.utf8).write(to: file, options: [.atomic, .completeFileProtection])
        return file
    }
}
