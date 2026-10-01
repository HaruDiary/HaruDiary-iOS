import Foundation

/// Writing kept on the device until it is saved or given up: it survives the app being closed and a save
/// that failed. Either a new diary, or the changes being made to a stored one.
/// Photos are not kept, only how many would have to be picked again.
struct StoredDiaryDraft: Codable, Equatable {
    var title: String
    var content: String
    var date: Date
    var emotion: String
    var weather: String
    /// New diary: its photos. Stored diary: the photos added while editing.
    var photoCount: Int
    /// Who was writing; nil before any account exists. Another account is never shown this draft.
    var userID: String?
    /// The stored diary being changed; nil for a new diary.
    var diaryID: String? = nil

    /// Nothing worth keeping: photos alone cannot be brought back, and a day picked without any writing is
    /// not kept on purpose. An empty editor opening on a past day would invite writing today's diary there.
    var isEmpty: Bool {
        title.isEmpty && content.isEmpty && emotion.isEmpty && weather.isEmpty
    }

    /// A draft written before an account existed belongs to whoever continues on this device.
    func belongs(to userID: String?) -> Bool {
        self.userID == nil || self.userID == userID
    }
}

/// One new diary's writing and one stored diary's changes are kept at a time.
@MainActor
protocol DiaryDraftStoring: AnyObject {
    /// `diaryID` nil asks for the new diary's writing; otherwise for the changes kept for that diary.
    func load(diaryID: String?) -> StoredDiaryDraft?
    func save(_ draft: StoredDiaryDraft)
    /// Clears the new diary's writing, or the kept changes when they are for `diaryID`.
    func clear(diaryID: String?)
    /// A save of `draft` started or ended. The editor closes when a save starts, so another editor can open
    /// while it runs: the writing stays kept (the app may be closed before the save ends), but it is not
    /// brought back into that editor.
    func setSaving(_ isSaving: Bool, _ draft: StoredDiaryDraft)
    func isBeingSaved(_ draft: StoredDiaryDraft) -> Bool
}
