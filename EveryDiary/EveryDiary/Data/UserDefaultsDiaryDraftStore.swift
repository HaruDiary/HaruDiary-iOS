import Foundation

@MainActor
final class UserDefaultsDiaryDraftStore: DiaryDraftStoring {
    static let key = "diaryDraft.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// A value that cannot be read (from a later version) counts as no draft.
    func load() -> StoredDiaryDraft? {
        defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(StoredDiaryDraft.self, from: $0) }
    }

    func save(_ draft: StoredDiaryDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
