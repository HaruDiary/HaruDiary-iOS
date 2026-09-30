import XCTest

final class InMemoryAppLockStore: AppLockStore {
    var passcodeRecord: String?
    var biometricsEnabled = false
    var legacyBiometricsEnabled = false
    var failedAttempts = 0
    var lockedUntil: Date?
}

@MainActor
final class AppLockTests: XCTestCase {
    private let store = InMemoryAppLockStore()
    private var now = Date(timeIntervalSince1970: 1_800_000_000)
    private lazy var lock = AppLock(store: store, now: { [unowned self] in now })

    func testPasscodeIsStoredOnlyAsSaltedHash() throws {
        lock.setPasscode("1234")
        let record = try XCTUnwrap(store.passcodeRecord)
        XCTAssertFalse(record.contains("1234"))
        XCTAssertEqual(lock.mode, .passcode(biometrics: false))
        XCTAssertTrue(lock.matches("1234"))
        XCTAssertFalse(lock.matches("4321"))

        // The same passcode set again gets a new salt.
        lock.setPasscode("1234")
        XCTAssertNotEqual(store.passcodeRecord, record)
    }

    func testOnlyFourDigitsAreValid() {
        XCTAssertTrue(AppLock.isValid("0000"))
        XCTAssertFalse(AppLock.isValid("123"))
        XCTAssertFalse(AppLock.isValid("12345"))
        XCTAssertFalse(AppLock.isValid("12a4"))
        XCTAssertFalse(AppLock.isValid("١٢٣٤"))
    }

    func testWrongPasscodesStartGrowingWaits() {
        lock.setPasscode("1234")
        for tries in [4, 3, 2, 1] {
            XCTAssertEqual(lock.unlock(with: "0000"), .wrong(triesBeforeWait: tries))
        }
        XCTAssertEqual(lock.unlock(with: "0000"), .wait(until: now.addingTimeInterval(30)))
        // Even the right passcode waits.
        XCTAssertEqual(lock.unlock(with: "1234"), .wait(until: now.addingTimeInterval(30)))

        now += 31
        XCTAssertNil(lock.waitUntil)
        XCTAssertEqual(lock.unlock(with: "0000"), .wait(until: now.addingTimeInterval(60)))
        XCTAssertEqual(AppLock.wait(afterFailures: 7), 300)
        XCTAssertEqual(AppLock.wait(afterFailures: 12), 900)
    }

    func testRightPasscodeClearsTheCount() {
        lock.setPasscode("1234")
        _ = lock.unlock(with: "0000")
        _ = lock.unlock(with: "0000")
        XCTAssertEqual(lock.unlock(with: "1234"), .unlocked)
        XCTAssertEqual(store.failedAttempts, 0)
        XCTAssertEqual(lock.unlock(with: "0000"), .wrong(triesBeforeWait: 4))
    }

    // The wait is kept in the store, so quitting the app does not skip it.
    func testWaitSurvivesARelaunch() {
        lock.setPasscode("1234")
        for _ in 0..<5 { _ = lock.unlock(with: "0000") }
        let relaunched = AppLock(store: store, now: { [unowned self] in now })
        XCTAssertEqual(relaunched.waitUntil, now.addingTimeInterval(30))
    }

    func testEarlierBiometricsLockMovesToPasscodeWithBiometrics() {
        store.legacyBiometricsEnabled = true
        XCTAssertEqual(lock.mode, .legacyBiometrics)
        XCTAssertTrue(lock.isEnabled)
        lock.setPasscode("2580")
        XCTAssertEqual(lock.mode, .passcode(biometrics: true))
        XCTAssertFalse(store.legacyBiometricsEnabled)
    }

    func testBiometricsNeedAPasscodeAndTurningOffClearsEverything() {
        lock.setBiometrics(true)
        XCTAssertEqual(lock.mode, .off)
        lock.setPasscode("1234")
        lock.setBiometrics(true)
        XCTAssertEqual(lock.mode, .passcode(biometrics: true))
        _ = lock.unlock(with: "0000")
        lock.turnOff()
        XCTAssertEqual(lock.mode, .off)
        XCTAssertNil(store.passcodeRecord)
        XCTAssertFalse(store.biometricsEnabled)
        XCTAssertEqual(store.failedAttempts, 0)
    }

    func testWaitMessageRoundsUp() {
        XCTAssertEqual(LockMessages.remaining(until: now.addingTimeInterval(29.2), now: now), "30초 후에 다시 시도하세요")
        XCTAssertEqual(LockMessages.remaining(until: now.addingTimeInterval(61), now: now), "2분 후에 다시 시도하세요")
    }
}
