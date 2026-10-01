import XCTest

final class AppTextSizeTests: XCTestCase {
    func testSystemSettingNeverOverridesThePhone() {
        for step in 0..<AppTextSize.stepCount {
            XCTAssertNil(AppTextSize.system.step(systemStep: step))
        }
    }

    func testLargeSettingsRaiseTextOnADefaultPhone() {
        XCTAssertEqual(AppTextSize.large.step(systemStep: AppTextSize.defaultStep), 6)
        XCTAssertEqual(AppTextSize.extraLarge.step(systemStep: AppTextSize.defaultStep), 8)
    }

    func testAppNeverShowsTextSmallerThanThePhoneAsksFor() {
        XCTAssertNil(AppTextSize.large.step(systemStep: 6), "Already as large: no override")
        XCTAssertNil(AppTextSize.large.step(systemStep: 9), "The phone's larger size is kept")
        XCTAssertNil(AppTextSize.extraLarge.step(systemStep: 11))
        XCTAssertEqual(AppTextSize.extraLarge.step(systemStep: 7), 8)
    }

    func testStoreRemembersTheChoiceAndFallsBackToSystem() throws {
        let suite = "AppTextSizeTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsTextSizeStore(defaults: defaults)
        XCTAssertEqual(store.textSize, .system)

        store.textSize = .extraLarge
        XCTAssertEqual(UserDefaultsTextSizeStore(defaults: defaults).textSize, .extraLarge)

        defaults.set("gigantic", forKey: UserDefaultsTextSizeStore.key)
        XCTAssertEqual(store.textSize, .system, "A value this version does not know follows the phone")
    }

    func testEveryOptionHasATitleForSettings() {
        XCTAssertEqual(AppTextSize.allCases.map(\.title), ["기본", "크게", "아주 크게"])
    }

    @MainActor
    func testControllerKeepsAndStoresTheSelection() {
        let store = MemoryTextSizeStore()
        store.textSize = .large
        let controller = AppTextSizeController(store: store)
        XCTAssertEqual(controller.setting, .large)
        XCTAssertEqual(AppTextSizeController.steps.count, AppTextSize.stepCount)
        XCTAssertEqual(AppTextSizeController.steps[AppTextSize.defaultStep], .large, "The system default text size")

        controller.select(.extraLarge)
        XCTAssertEqual(controller.setting, .extraLarge)
        XCTAssertEqual(store.textSize, .extraLarge)
    }

    // MARK: - Light and dark

    func testAppearanceStoreRemembersTheChoiceAndFallsBackToThePhone() throws {
        let suite = "AppAppearanceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsAppearanceStore(defaults: defaults)
        XCTAssertEqual(store.appearance, .system)

        store.appearance = .dark
        XCTAssertEqual(UserDefaultsAppearanceStore(defaults: defaults).appearance, .dark)

        defaults.set("sepia", forKey: UserDefaultsAppearanceStore.key)
        XCTAssertEqual(store.appearance, .system, "A value this version does not know follows the phone")
    }

    @MainActor
    func testAppearanceIsAppliedToWindowsAttachedBeforeAndAfterTheChoice() throws {
        let suite = "AppAppearanceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = AppAppearanceController(store: UserDefaultsAppearanceStore(defaults: defaults))
        let main = UIWindow()
        controller.attach(to: main)
        XCTAssertEqual(main.overrideUserInterfaceStyle, .unspecified, "Following the phone needs no override")

        controller.select(.dark)
        XCTAssertEqual(main.overrideUserInterfaceStyle, .dark)
        XCTAssertEqual(UserDefaultsAppearanceStore(defaults: defaults).appearance, .dark)

        // A window made later, such as the lock screen's.
        let lock = UIWindow()
        controller.attach(to: lock)
        XCTAssertEqual(lock.overrideUserInterfaceStyle, .dark)

        controller.select(.light)
        XCTAssertEqual(main.overrideUserInterfaceStyle, .light)
        XCTAssertEqual(lock.overrideUserInterfaceStyle, .light)
        XCTAssertEqual(AppAppearance.allCases.map(\.title), ["시스템 설정", "라이트", "다크"])
    }
}

private final class MemoryTextSizeStore: AppTextSizeStoring {
    var textSize: AppTextSize = .system
}
