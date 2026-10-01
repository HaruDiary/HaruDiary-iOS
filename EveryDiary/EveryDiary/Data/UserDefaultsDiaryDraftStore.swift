import Foundation

@MainActor
final class UserDefaultsDiaryDraftStore: DiaryDraftStoring {
    /// The writing of a new diary.
    static let key = "diaryDraft.v1"
    /// The changes being made to a stored diary; the latest edited diary only.
    static let editKey = "diaryDraft.edit.v1"
    private let defaults: UserDefaults
    /// Drafts whose save is running. Only for as long as the app runs: after a restart no save is running.
    private var saving: [StoredDiaryDraft] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// A value that cannot be read (from a later version) counts as no draft.
    func load(diaryID: String?) -> StoredDiaryDraft? {
        guard let draft = read(diaryID == nil ? Self.key : Self.editKey) else { return nil }
        return draft.diaryID == diaryID ? draft : nil
    }

    func save(_ draft: StoredDiaryDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: draft.diaryID == nil ? Self.key : Self.editKey)
    }

    func clear(diaryID: String?) {
        guard let diaryID else {
            defaults.removeObject(forKey: Self.key)
            return
        }
        // Changes kept for another diary are left alone.
        if read(Self.editKey)?.diaryID == diaryID { defaults.removeObject(forKey: Self.editKey) }
    }

    func setSaving(_ isSaving: Bool, _ draft: StoredDiaryDraft) {
        saving.removeAll { $0 == draft }
        if isSaving { saving.append(draft) }
    }

    func isBeingSaved(_ draft: StoredDiaryDraft) -> Bool {
        saving.contains(draft)
    }

    private func read(_ key: String) -> StoredDiaryDraft? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(StoredDiaryDraft.self, from: $0) }
    }
}
