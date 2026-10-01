import Foundation

/// The writing of a new diary, kept on the device until the diary is saved or the writing is given up:
/// it survives the app being closed and a save that failed. Photos are not kept, only how many there were.
struct StoredDiaryDraft: Codable, Equatable {
    var title: String
    var content: String
    var date: Date
    var emotion: String
    var weather: String
    var photoCount: Int
    /// Who was writing; nil before any account exists. Another account is never shown this draft.
    var userID: String?

    /// Nothing worth keeping: photos alone cannot be brought back.
    var isEmpty: Bool {
        title.isEmpty && content.isEmpty && emotion.isEmpty && weather.isEmpty
    }

    /// A draft written before an account existed belongs to whoever continues on this device.
    func belongs(to userID: String?) -> Bool {
        self.userID == nil || self.userID == userID
    }
}

@MainActor
protocol DiaryDraftStoring: AnyObject {
    func load() -> StoredDiaryDraft?
    func save(_ draft: StoredDiaryDraft)
    func clear()
}
