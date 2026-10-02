import Foundation

/// The widget's snapshot in the defaults the app and the widget share (the app group).
struct UserDefaultsDiaryWidgetStore: DiaryWidgetSnapshotStoring {
    static let key = "diaryWidgetSnapshot.v1"
    let defaults: UserDefaults?

    /// Nil defaults (the app group is missing from the build's entitlements) read as empty and keep nothing.
    init(defaults: UserDefaults? = UserDefaults(suiteName: DiaryWidgetShared.appGroup)) {
        self.defaults = defaults
    }

    /// A value that cannot be read (from a later version) counts as nothing written.
    func load() -> DiaryWidgetSnapshot {
        defaults?.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(DiaryWidgetSnapshot.self, from: $0) } ?? .empty
    }

    func save(_ snapshot: DiaryWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: Self.key)
    }
}
