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
