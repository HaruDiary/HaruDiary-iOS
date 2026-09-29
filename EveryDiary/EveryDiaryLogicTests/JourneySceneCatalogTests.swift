import CoreGraphics
import XCTest

final class JourneySceneCatalogTests: XCTestCase {
    private let longestMonth = [1: 31, 2: 29, 3: 31, 4: 30, 5: 31, 6: 30, 7: 31, 8: 31, 9: 30, 10: 31, 11: 30, 12: 31]

    func testEveryMonthHasItsOwnPictureWithALightForEachDay() {
        var titles = Set<String>()
        for month in 1...12 {
            let scene = JourneySceneCatalog.scene(for: month)
            XCTAssertEqual(scene.month, month)
            XCTAssertGreaterThanOrEqual(scene.lights.count, longestMonth[month]!, "month \(month)")
            titles.insert(scene.title)
        }
        XCTAssertEqual(titles.count, 12)
    }

    func testEveryMonthAddsSomethingWhenCompleted() {
        for month in 1...12 {
            let scene = JourneySceneCatalog.scene(for: month)
            XCTAssertFalse(scene.completion.isEmpty, "month \(month)")
            XCTAssertFalse(scene.ambience.isEmpty, "month \(month)")
        }
    }

    func testStillStandInsGiveWayToTheAnimation() {
        // February has no still copy of its animation; every other month hides one while it moves.
        for month in [1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] {
            let scene = JourneySceneCatalog.scene(for: month)
            XCTAssertTrue((scene.background + scene.completion).contains(where: \.isStill), "month \(month)")
        }
        // Light slots and the picture itself are never still stand-ins.
        let january = JourneySceneCatalog.scene(for: 1)
        XCTAssertEqual(january.background.filter { !$0.isStill }.count, january.background.count - 1)
    }

    func testLightsTurnOnInAShuffledOrderThatStaysTheSame() {
        for month in 1...12 {
            let scene = JourneySceneCatalog.scene(for: month)
            let days = longestMonth[month]!
            let order = scene.lightingOrder(slotCount: days, year: 2026)
            XCTAssertEqual(order.sorted(), Array(0..<days), "month \(month) must use every slot once")
            XCTAssertEqual(order, scene.lightingOrder(slotCount: days, year: 2026), "month \(month) must not reshuffle")
            XCTAssertNotEqual(order, Array(0..<days), "month \(month) should not light in drawing order")
        }
    }

    func testEachYearGetsItsOwnOrder() {
        let scene = JourneySceneCatalog.scene(for: 5)
        XCTAssertNotEqual(scene.lightingOrder(slotCount: 31, year: 2026), scene.lightingOrder(slotCount: 31, year: 2027))
    }

    func testFebruaryOnlyUsesTheDaysOfThatYear() {
        let scene = JourneySceneCatalog.scene(for: 2)
        XCTAssertEqual(scene.lightingOrder(slotCount: 28, year: 2026).sorted(), Array(0..<28))
        XCTAssertEqual(scene.lightingOrder(slotCount: 29, year: 2028).sorted(), Array(0..<29))
    }

    func testTheStarOnTheTreeStaysLast() {
        let order = JourneySceneCatalog.scene(for: 12).lightingOrder(slotCount: 31, year: 2026)
        XCTAssertEqual(order.last, 30)
    }

    func testLightsStayInsideTheCanvasAndDoNotShareAPlace() {
        let canvas = CGRect(origin: .zero, size: JourneyScene.canvas).insetBy(dx: -12, dy: -12)
        for month in 1...12 {
            let lights = JourneySceneCatalog.scene(for: month).lights.prefix(longestMonth[month]!)
            let boxes = lights.map { $0.path.boundingBoxOfPath }
            for box in boxes {
                XCTAssertTrue(canvas.contains(box), "month \(month) light at \(box)")
            }
            let centers = Set(boxes.map { "\(Int($0.midX)),\(Int($0.midY))" })
            XCTAssertEqual(centers.count, boxes.count, "month \(month) has lights on top of each other")
        }
    }

    func testPicturesAreTheSameOnEveryLaunch() {
        for month in [3, 6, 7, 8, 9] {
            let first = JourneySceneCatalog.scene(for: month).lights.map { $0.path.boundingBoxOfPath }
            let second = JourneySceneCatalog.scene(for: month).lights.map { $0.path.boundingBoxOfPath }
            XCTAssertEqual(first, second)
        }
    }

    func testNovemberKeepsTheOriginalWindowOrder() {
        let windows = JourneySceneCatalog.scene(for: 11).lights.map { $0.path.boundingBoxOfPath }
        XCTAssertEqual(windows.count, 31)
        // As in BuildingView: the first lit window is the second slot of the left building's lowest floor.
        XCTAssertEqual(windows[0].origin.x, 27.3, accuracy: 0.01)
        XCTAssertEqual(windows[0].origin.y, 637, accuracy: 0.01)
        XCTAssertEqual(windows[0].size, CGSize(width: 10, height: 22))
    }
}
