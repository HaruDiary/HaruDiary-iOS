import Foundation

/// Replaces a stored diary's photos so that a failed step never loses the photos it already has.
///
/// Order: upload the new photos → save the diary with the new URLs → delete the previous files.
/// If an upload or the save fails, the stored diary keeps its previous URLs and files,
/// and any newly uploaded files are removed so they do not become orphans.
enum DiaryPhotoReplacement {
    enum Outcome: Equatable {
        case updated
        case uploadFailed(failedCount: Int)
        case saveFailed
    }

    @MainActor
    static func replace(
        previousURLs: [String],
        upload: () async -> [String?],
        save: ([String]) async -> Bool,
        delete: ([String]) async -> Void
    ) async -> Outcome {
        let results = await upload()
        let uploaded = results.compactMap { $0 }
        let failedCount = results.count - uploaded.count
        guard failedCount == 0 else {
            await delete(uploaded)
            return .uploadFailed(failedCount: failedCount)
        }
        guard await save(uploaded) else {
            await delete(uploaded)
            return .saveFailed
        }
        let replaced = previousURLs.filter { !uploaded.contains($0) }
        await delete(replaced)
        return .updated
    }
}
