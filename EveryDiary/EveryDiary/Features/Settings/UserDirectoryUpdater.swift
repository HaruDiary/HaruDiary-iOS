import CryptoKit
import Foundation

/// Keeps `users/{userID}` describing the signed-in account for as long as the app runs.
/// A write that fails (offline, or rules that do not allow it) is only logged: nothing in the app depends on it.
@MainActor
final class UserDirectoryUpdater {
    private let session: any AccountSession
    private let directory: any UserDirectoryWriting
    private let records: any UserDirectoryRecordStoring
    private let calendar: Calendar
    private let now: () -> Date
    private var observation: Task<Void, Never>?

    init(session: any AccountSession, directory: any UserDirectoryWriting, records: any UserDirectoryRecordStoring,
         calendar: Calendar, now: @escaping () -> Date) {
        self.session = session
        self.directory = directory
        self.records = records
        self.calendar = calendar
        self.now = now
    }

    deinit {
        observation?.cancel()
    }

    func start() {
        guard observation == nil else { return }
        let accounts = session.observeAccount()
        observation = Task { [weak self] in
            for await snapshot in accounts {
                guard !Task.isCancelled else { return }
                await self?.update(snapshot)
            }
        }
    }

    func stop() {
        observation?.cancel()
        observation = nil
    }

    private func update(_ snapshot: AccountSnapshot?) async {
        guard let snapshot, let userID = snapshot.userID, let entry = UserDirectoryEntry(snapshot) else { return }
        let seenAt = now()
        // The same account on the same day is written once; a changed nickname, e-mail or sign-in method at once.
        let record = Self.record(entry, day: calendar.startOfDay(for: seenAt))
        guard records.lastWritten(userID: userID) != record else { return }
        do {
            try await directory.write(entry, userID: userID, seenAt: seenAt)
            records.setLastWritten(record, userID: userID)
        } catch {
            let error = error as NSError
            print("User directory not updated: \(error.domain) \(error.code)")
        }
    }

    /// A digest, so the nickname and e-mail are not left readable on the device, also after a sign-out or a withdrawal.
    static func record(_ entry: UserDirectoryEntry, day: Date) -> String {
        let content = [entry.supportCode, entry.nickname ?? "", entry.provider, entry.email ?? "", String(Int(day.timeIntervalSince1970))]
            .joined(separator: "\u{1F}")
        return SHA256.hash(data: Data(content.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// What was last written for each account, kept on the device.
struct UserDefaultsUserDirectoryRecords: UserDirectoryRecordStoring {
    static let keyPrefix = "userDirectory.lastWritten."
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastWritten(userID: String) -> String? {
        defaults.string(forKey: Self.keyPrefix + userID)
    }

    func setLastWritten(_ record: String, userID: String) {
        defaults.set(record, forKey: Self.keyPrefix + userID)
    }
}

extension AppDependencies {
    /// Nil where no directory is set up (tests, previews).
    func makeUserDirectoryUpdater() -> UserDirectoryUpdater? {
        userDirectory.map {
            UserDirectoryUpdater(session: accountSession, directory: $0, records: UserDefaultsUserDirectoryRecords(),
                                 calendar: calendar, now: now)
        }
    }
}
