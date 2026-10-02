import XCTest

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testFirstLaunchStartsAtRecordWithoutCompleting() {
        let store = ProgressStore()
        let model = OnboardingViewModel(store: store)
        XCTAssertEqual(model.selectedPage, .record)
        XCTAssertFalse(model.isCompleted)
        XCTAssertEqual(store.writes, 0)
    }

    func testNextVisitsAllPagesBeforeCompleting() {
        let store = ProgressStore()
        let model = OnboardingViewModel(store: store)
        XCTAssertEqual(OnboardingPage.allCases.map(\.chapter), ["기록", "캘린더", "다시 보기", "여정", "보관"])
        XCTAssertEqual(OnboardingPage.allCases.count, 5)
        for expectedIndex in 1..<5 {
            model.advance()
            XCTAssertEqual(model.selectedPage.rawValue, expectedIndex)
            XCTAssertFalse(model.isCompleted)
            XCTAssertEqual(model.isLastPage, expectedIndex == 4)
        }
        XCTAssertTrue(model.isLastPage)
        XCTAssertFalse(store.hasCompletedOnboarding)
        model.advance()
        XCTAssertTrue(model.isCompleted)
        XCTAssertTrue(store.hasCompletedOnboarding)
    }

    func testSwipeBackUpdatesNextDestination() {
        let model = OnboardingViewModel(store: ProgressStore())
        model.select(.keep)
        model.select(.record)
        model.advance()
        XCTAssertEqual(model.selectedPage.rawValue, 1)
        XCTAssertFalse(model.isCompleted)
    }

    func testSkipCompletesFromEveryPage() {
        for page in OnboardingPage.allCases {
            let store = ProgressStore()
            let model = OnboardingViewModel(store: store)
            model.select(page)
            model.skip()
            XCTAssertTrue(store.hasCompletedOnboarding)
            XCTAssertTrue(model.isCompleted)
        }
    }

    func testRepeatedCompletionAndLatePageEventsAreIgnored() {
        let store = ProgressStore()
        let model = OnboardingViewModel(store: store)
        model.select(.keep)
        model.advance()
        model.skip()
        model.advance()
        model.select(.record)
        XCTAssertEqual(store.writes, 1)
        XCTAssertEqual(model.selectedPage, .keep)
    }

    func testReturningUserRemainsCompletedWithoutRewritingProgress() {
        let store = ProgressStore(completed: true)
        let model = OnboardingViewModel(store: store)
        XCTAssertTrue(model.isCompleted)
        model.advance()
        model.skip()
        XCTAssertEqual(store.writes, 0)
    }

    func testInterruptedOnboardingRemainsIncomplete() {
        let store = ProgressStore()
        var model: OnboardingViewModel? = OnboardingViewModel(store: store)
        model?.advance()
        model = nil
        let relaunched = OnboardingViewModel(store: store)
        XCTAssertFalse(relaunched.isCompleted)
        XCTAssertEqual(relaunched.selectedPage, .record)
    }

    func testCompletionIsVisibleToNextLaunch() {
        let store = ProgressStore()
        OnboardingViewModel(store: store).skip()
        XCTAssertTrue(OnboardingViewModel(store: store).isCompleted)
    }

    func testExistingDefaultsKeyRemainsCompatibleAndOtherSettingsStayIntact() throws {
        let suite = "OnboardingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "hasSeenOnboarding")
        defaults.set(true, forKey: "BiometricsEnabled")
        let store = UserDefaultsOnboardingProgressStore(defaults: defaults)
        XCTAssertTrue(store.hasCompletedOnboarding)
        store.hasCompletedOnboarding = false
        OnboardingViewModel(store: store).skip()
        XCTAssertTrue(defaults.bool(forKey: "hasSeenOnboarding"))
        XCTAssertTrue(defaults.bool(forKey: "BiometricsEnabled"))
    }
}

@MainActor
private final class ProgressStore: OnboardingProgressStore {
    var writes = 0
    var hasCompletedOnboarding: Bool { didSet { writes += 1 } }

    init(completed: Bool = false) {
        hasCompletedOnboarding = completed
    }
}
