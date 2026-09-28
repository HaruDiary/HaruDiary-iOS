import Foundation
import XCTest

@MainActor
final class DiaryPhotoReplacementTests: XCTestCase {
    private final class Recorder {
        var steps: [String] = []
        var saved: [String]?
        var deleted: [[String]] = []
    }

    private func run(previous: [String], uploads: [String?], saveSucceeds: Bool = true) async -> (DiaryPhotoReplacement.Outcome, Recorder) {
        let recorder = Recorder()
        let outcome = await DiaryPhotoReplacement.replace(
            previousURLs: previous,
            upload: {
                recorder.steps.append("upload")
                return uploads
            },
            save: { urls in
                recorder.steps.append("save")
                recorder.saved = urls
                return saveSucceeds
            },
            delete: { urls in
                recorder.steps.append("delete")
                recorder.deleted.append(urls)
            }
        )
        return (outcome, recorder)
    }

    func testSuccessfulReplacementSavesBeforeDeletingPreviousFiles() async {
        let (outcome, recorder) = await run(previous: ["old-1", "old-2"], uploads: ["new-1", "new-2"])

        XCTAssertEqual(outcome, .updated)
        XCTAssertEqual(recorder.steps, ["upload", "save", "delete"])
        XCTAssertEqual(recorder.saved, ["new-1", "new-2"])
        XCTAssertEqual(recorder.deleted, [["old-1", "old-2"]])
    }

    func testFailedUploadKeepsStoredPhotosAndRemovesPartialUploads() async {
        let (outcome, recorder) = await run(previous: ["old-1"], uploads: ["new-1", nil])

        XCTAssertEqual(outcome, .uploadFailed(failedCount: 1))
        XCTAssertNil(recorder.saved, "The diary must not be saved without its photos")
        XCTAssertEqual(recorder.deleted, [["new-1"]], "Only the orphaned new upload is removed")
    }

    func testFailedSaveKeepsPreviousFilesAndRemovesNewUploads() async {
        let (outcome, recorder) = await run(previous: ["old-1"], uploads: ["new-1"], saveSucceeds: false)

        XCTAssertEqual(outcome, .saveFailed)
        XCTAssertEqual(recorder.deleted, [["new-1"]])
    }

    func testRemovingAllPhotosSavesEmptyListThenDeletesPreviousFiles() async {
        let (outcome, recorder) = await run(previous: ["old-1"], uploads: [])

        XCTAssertEqual(outcome, .updated)
        XCTAssertEqual(recorder.saved, [])
        XCTAssertEqual(recorder.deleted, [["old-1"]])
    }

    func testURLStillInUseIsNotDeleted() async {
        let (_, recorder) = await run(previous: ["kept", "old"], uploads: ["kept", "new"])

        XCTAssertEqual(recorder.deleted, [["old"]])
    }
}
