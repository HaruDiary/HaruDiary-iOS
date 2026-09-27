import Foundation
import XCTest

final class DiaryDocumentDecodingTests: XCTestCase {
    private struct StoredDocument {
        let id: String
        let json: String
    }

    private func decode(_ documents: [StoredDocument]) -> DiaryDocumentDecoding.Result {
        DiaryDocumentDecoding.decode(documents, documentID: \.id) { document in
            try JSONDecoder().decode(DiaryEntry.self, from: Data(document.json.utf8))
        }
    }

    private func valid(_ title: String) -> String {
        #"{"title":"\#(title)","content":"본문","dateString":"2026-09-01 09:00:00 +0900","emotion":"","weather":"","isDeleted":false,"useMetadataLocation":false}"#
    }

    func testOneMalformedDocumentDoesNotHideTheOthers() {
        let result = decode([
            StoredDocument(id: "first", json: valid("첫 기록")),
            StoredDocument(id: "broken", json: #"{"title":"본문 없음"}"#),
            StoredDocument(id: "third", json: valid("세 번째")),
        ])

        XCTAssertEqual(result.entries.map(\.id), ["first", "third"])
        XCTAssertEqual(result.skippedCount, 1)
    }

    func testDocumentIDReplacesMissingOrStaleStoredID() {
        let stale = #"{"id":"old-id","title":"기록","content":"본문","dateString":"2026-09-01 09:00:00 +0900","emotion":"","weather":"","isDeleted":false,"useMetadataLocation":false}"#
        let result = decode([
            StoredDocument(id: "doc-without-id", json: valid("기록")),
            StoredDocument(id: "doc-with-stale-id", json: stale),
        ])

        XCTAssertEqual(result.entries.map(\.id), ["doc-without-id", "doc-with-stale-id"])
    }

    func testOnlyMalformedDocumentsYieldAnEmptySuccessfulResult() {
        let result = decode([StoredDocument(id: "broken", json: "{}")])

        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.skippedCount, 1)
    }
}
