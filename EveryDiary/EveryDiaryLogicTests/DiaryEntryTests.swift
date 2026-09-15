import Foundation
import XCTest

final class DiaryEntryTests: XCTestCase {
    private func legacyEntry() throws -> DiaryEntry {
        let json = #"""
        {
          "id": "diary-1", "title": "첫 기록", "content": "본문",
          "dateString": "2026-09-01 00:30:00 +0900",
          "emotion": "좋음", "weather": "맑음", "userID": "test-user",
          "isDeleted": false, "useMetadataLocation": false
        }
        """#
        return try JSONDecoder().decode(DiaryEntry.self, from: Data(json.utf8))
    }

    func testDecodesExistingDiaryWithoutOptionalImageAndWeatherFields() throws {
        let entry = try legacyEntry()
        XCTAssertEqual(entry.id, "diary-1")
        XCTAssertEqual(entry.title, "첫 기록")
        XCTAssertEqual(entry.userID, "test-user")
        XCTAssertNil(entry.imageURL)
        XCTAssertNil(entry.weatherTemp)
        XCTAssertNil(entry.deleteDate)
    }

    func testDatePreservesStoredOffsetAcrossMonthBoundary() throws {
        let entry = try legacyEntry()
        let expected = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-31T15:30:00Z"))
        XCTAssertEqual(entry.date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.001)
    }

    func testEncodingRetainsExistingStorageFieldNames() throws {
        let data = try JSONEncoder().encode(legacyEntry())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["dateString"] as? String, "2026-09-01 00:30:00 +0900")
        XCTAssertEqual(object["userID"] as? String, "test-user")
        XCTAssertEqual(object["isDeleted"] as? Bool, false)
        XCTAssertEqual(object["useMetadataLocation"] as? Bool, false)
        XCTAssertNil(object["date"])
    }

    func testDeletedDiaryRoundTripPreservesRecoveryAndImageInformation() throws {
        var entry = try legacyEntry()
        entry.isDeleted = true
        entry.deleteDate = Date(timeIntervalSince1970: 1_790_000_000)
        entry.imageURL = ["https://example.invalid/first.jpg", "https://example.invalid/second.jpg"]
        entry.useMetadataLocation = true
        entry.currentLocationInfo = "테스트 위치"
        let decoded = try JSONDecoder().decode(DiaryEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertTrue(decoded.isDeleted)
        XCTAssertEqual(decoded.deleteDate, entry.deleteDate)
        XCTAssertEqual(decoded.imageURL, entry.imageURL)
        XCTAssertTrue(decoded.useMetadataLocation)
        XCTAssertEqual(decoded.currentLocationInfo, entry.currentLocationInfo)
    }

    func testNewDiaryDefaultsToActiveWithoutMetadataLocation() {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let entry = DiaryEntry(title: "새 기록", content: "본문", date: date, emotion: "좋음", weather: "맑음")
        XCTAssertFalse(entry.isDeleted)
        XCTAssertFalse(entry.useMetadataLocation)
        XCTAssertNil(entry.deleteDate)
        XCTAssertNil(entry.id)
        XCTAssertEqual(entry.date.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testMissingRequiredContentIsRejectedInsteadOfCreatingAnEmptyDiary() throws {
        let data = Data(#"{"title":"제목"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(DiaryEntry.self, from: data)) { error in
            guard case DecodingError.keyNotFound = error else {
                return XCTFail("Expected a missing required field, received \(error)")
            }
        }
    }
}
