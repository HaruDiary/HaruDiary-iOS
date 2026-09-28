import Foundation

/// Decodes each stored diary document on its own so one malformed record cannot hide every other diary.
enum DiaryDocumentDecoding {
    struct Result {
        let entries: [DiaryEntry]
        /// Documents that could not be decoded; they are left untouched in storage.
        let skippedCount: Int
    }

    static func decode<Document>(_ documents: [Document], documentID: (Document) -> String,
                                 entry: (Document) throws -> DiaryEntry) -> Result {
        var entries: [DiaryEntry] = []
        var skippedCount = 0
        for document in documents {
            guard var decoded = try? entry(document) else {
                skippedCount += 1
                continue
            }
            // Navigation uses the existing document identity, including legacy records without an id field.
            decoded.id = documentID(document)
            entries.append(decoded)
        }
        return Result(entries: entries, skippedCount: skippedCount)
    }
}
