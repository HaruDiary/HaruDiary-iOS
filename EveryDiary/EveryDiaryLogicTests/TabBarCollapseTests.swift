import XCTest

final class TabBarCollapseTests: XCTestCase {
    func testScrollingDownShrinksAndScrollingUpGrows() {
        var collapse = TabBarCollapse()
        for offset in stride(from: CGFloat(0), through: 200, by: 10) { collapse.scrolled(to: offset) }
        XCTAssertTrue(collapse.isCollapsed)

        collapse.scrolled(to: 195)
        XCTAssertTrue(collapse.isCollapsed, "A small move back is ignored")
        collapse.scrolled(to: 180)
        XCTAssertFalse(collapse.isCollapsed)
    }

    func testTurningIsMeasuredFromWhereTheScrollTurned() {
        var collapse = TabBarCollapse()
        collapse.scrolled(to: 100)
        collapse.scrolled(to: 400)
        XCTAssertTrue(collapse.isCollapsed)
        collapse.scrolled(to: 800)
        collapse.scrolled(to: 790)
        XCTAssertTrue(collapse.isCollapsed)
        collapse.scrolled(to: 780)
        XCTAssertFalse(collapse.isCollapsed)
    }

    func testTopOfContentAlwaysShowsFullBar() {
        var collapse = TabBarCollapse()
        collapse.scrolled(to: 50)
        collapse.scrolled(to: 300)
        XCTAssertTrue(collapse.isCollapsed)
        collapse.scrolled(to: 10)
        XCTAssertFalse(collapse.isCollapsed)
        // Rubber-banding above the top never shrinks it.
        collapse.scrolled(to: -40)
        XCTAssertFalse(collapse.isCollapsed)
    }

    func testExpandingRestartsFromTheCurrentPlace() {
        var collapse = TabBarCollapse()
        collapse.scrolled(to: 50)
        collapse.scrolled(to: 300)
        collapse.expand(at: 300)
        XCTAssertFalse(collapse.isCollapsed)
        collapse.scrolled(to: 305)
        XCTAssertFalse(collapse.isCollapsed, "A tiny move after tapping does not shrink it again")
        collapse.scrolled(to: 330)
        XCTAssertTrue(collapse.isCollapsed)
    }
}
