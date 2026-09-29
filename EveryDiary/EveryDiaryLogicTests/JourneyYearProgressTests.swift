import XCTest

final class JourneyYearProgressTests: XCTestCase {
    private func progress(_ days: Int) -> JourneyYearProgress {
        JourneyYearProgress(year: 2026, daysWritten: days)
    }

    func testEveryThirtyDaysRaiseTheCityOneStage() {
        XCTAssertEqual(progress(0).stage, 0)
        XCTAssertEqual(progress(29).stage, 0)
        XCTAssertEqual(progress(30).stage, 1)
        XCTAssertEqual(progress(59).stage, 1)
        XCTAssertEqual(progress(180).stage, 6)
        XCTAssertEqual(progress(359).stage, 11)
        XCTAssertEqual(progress(360).stage, 12)
        XCTAssertEqual(progress(366).stage, 12)
    }

    func testDaysToTheNextStage() {
        XCTAssertEqual(progress(0).daysToNextStage, 30)
        XCTAssertEqual(progress(29).daysToNextStage, 1)
        XCTAssertEqual(progress(30).daysToNextStage, 30)
        XCTAssertEqual(progress(355).daysToNextStage, 5)
        XCTAssertNil(progress(360).daysToNextStage)
    }

    func testProgressWithinTheStage() {
        XCTAssertEqual(progress(0).stageProgress, 0)
        XCTAssertEqual(progress(45).stageProgress, 0.5, accuracy: 0.001)
        XCTAssertEqual(progress(365).stageProgress, 1)
    }

    func testEveryStageHasATitleAndAddsSomething() {
        XCTAssertEqual(JourneyCityScene.stageTitles.count, JourneyYearProgress.finalStage + 1)
        for stage in 0...JourneyYearProgress.finalStage {
            XCTAssertTrue(JourneyCityScene.pieces.contains { $0.stage == stage }, "stage \(stage) adds nothing")
        }
        // The wasteland props are gone once the city turns green.
        XCTAssertLessThan(JourneyCityScene.elements(for: 5).count - JourneyCityScene.elements(for: 4).count,
                          JourneyCityScene.pieces.filter { $0.stage == 5 }.count)
    }
}
