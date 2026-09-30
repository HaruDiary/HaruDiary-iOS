import XCTest

@MainActor
final class FakeDeviceOwner: DeviceOwnerAuthenticating {
    var biometry: Biometry = .faceID
    var biometricsSucceed = true
    var ownerSucceeds = true
    private(set) var biometricRequests = 0
    private(set) var ownerRequests = 0

    func authenticateWithBiometrics(reason: String) async -> Bool {
        biometricRequests += 1
        return biometricsSucceed
    }

    func authenticateDeviceOwner(reason: String) async -> Bool {
        ownerRequests += 1
        return ownerSucceeds
    }
}

@MainActor
final class LockViewModelTests: XCTestCase {
    private let store = InMemoryAppLockStore()
    private let owner = FakeDeviceOwner()
    private lazy var lock = AppLock(store: store)

    private func enter(_ passcode: String, into type: (Int) -> Void) {
        passcode.compactMap(\.wholeNumberValue).forEach(type)
    }

    // MARK: - Lock screen

    func testRightPasscodeUnlocksAndWrongOneShakes() throws {
        try lock.setPasscode("1234")
        let screen = LockScreenViewModel(lock: lock, owner: owner)
        enter("1111", into: screen.type)
        XCTAssertNil(screen.outcome)
        XCTAssertEqual(screen.mistakes, 1)
        XCTAssertEqual(screen.digits, "")
        enter("1234", into: screen.type)
        XCTAssertEqual(screen.outcome, .unlocked)
    }

    func testFaceIDIsAskedOnlyOnceWhenTheLockAppears() async throws {
        try lock.setPasscode("1234")
        lock.setBiometrics(true)
        owner.biometricsSucceed = false
        let screen = LockScreenViewModel(lock: lock, owner: owner)
        XCTAssertEqual(screen.biometryName, "Face ID")
        await screen.promptBiometricsOnce()
        await screen.promptBiometricsOnce()
        XCTAssertEqual(owner.biometricRequests, 1)
        XCTAssertNil(screen.outcome)

        owner.biometricsSucceed = true
        await screen.useBiometrics()
        XCTAssertEqual(screen.outcome, .unlocked)
    }

    func testFaceIDIsNotOfferedWhenOffOrUnavailable() async throws {
        try lock.setPasscode("1234")
        let screen = LockScreenViewModel(lock: lock, owner: owner)
        XCTAssertNil(screen.biometryName)
        await screen.promptBiometricsOnce()
        XCTAssertEqual(owner.biometricRequests, 0)

        lock.setBiometrics(true)
        owner.biometry = .none
        XCTAssertNil(screen.biometryName)
    }

    func testForgottenPasscodeTurnsTheLockOffAfterTheIPhonePasscode() async throws {
        try lock.setPasscode("1234")
        let screen = LockScreenViewModel(lock: lock, owner: owner)
        owner.ownerSucceeds = false
        await screen.forgotPasscode()
        XCTAssertNil(screen.outcome)
        XCTAssertTrue(lock.isEnabled)

        owner.ownerSucceeds = true
        await screen.forgotPasscode()
        XCTAssertEqual(screen.outcome, .unlockedAndTurnedOff)
        XCTAssertEqual(lock.mode, .off)
    }

    func testEarlierLockUnlocksAsBeforeAndThenAsksForAPasscode() async {
        store.legacyBiometricsEnabled = true
        let screen = LockScreenViewModel(lock: lock, owner: owner)
        XCTAssertTrue(screen.isLegacy)
        await screen.promptBiometricsOnce()
        XCTAssertEqual(owner.ownerRequests, 1)
        XCTAssertEqual(screen.outcome, .unlockedAskingForPasscode)
        XCTAssertEqual(lock.mode, .legacyBiometrics)
    }

    func testKeypadIsIgnoredDuringAWait() throws {
        try lock.setPasscode("1234")
        let screen = LockScreenViewModel(lock: lock, owner: owner)
        for _ in 0..<5 { enter("0000", into: screen.type) }
        XCTAssertNotNil(screen.waitUntil)
        XCTAssertEqual(screen.message, LockMessages.waiting)
        enter("1234", into: screen.type)
        XCTAssertNil(screen.outcome)
        XCTAssertEqual(screen.digits, "")
    }

    // MARK: - Passcode flow

    func testCreatingNeedsTheSamePasscodeTwice() {
        let flow = PasscodeFlowViewModel(purpose: .create, lock: lock)
        XCTAssertEqual(flow.step, .new)
        enter("1234", into: flow.type)
        XCTAssertEqual(flow.step, .confirm)
        enter("1235", into: flow.type)
        XCTAssertEqual(flow.step, .new)
        XCTAssertEqual(flow.mistakes, 1)
        XCTAssertEqual(lock.mode, .off)

        enter("2580", into: flow.type)
        enter("2580", into: flow.type)
        XCTAssertTrue(flow.isDone)
        XCTAssertTrue(lock.matches("2580"))
    }

    func testUnsavedPasscodeKeepsTheSheetOpenAndAsksAgain() {
        store.failsToSave = true
        let flow = PasscodeFlowViewModel(purpose: .create, lock: lock)
        enter("1234", into: flow.type)
        enter("1234", into: flow.type)
        XCTAssertFalse(flow.isDone)
        XCTAssertEqual(flow.step, .new)
        XCTAssertEqual(flow.message, "암호를 저장하지 못했어요. 다시 입력해주세요.")
        XCTAssertEqual(lock.mode, .off)
    }

    func testChangingAndTurningOffAskForTheCurrentPasscode() throws {
        try lock.setPasscode("1234")
        let change = PasscodeFlowViewModel(purpose: .change, lock: lock)
        XCTAssertEqual(change.step, .current)
        enter("0000", into: change.type)
        XCTAssertEqual(change.step, .current)
        enter("1234", into: change.type)
        enter("5678", into: change.type)
        enter("5678", into: change.type)
        XCTAssertTrue(change.isDone)
        XCTAssertTrue(lock.matches("5678"))

        let turnOff = PasscodeFlowViewModel(purpose: .turnOff, lock: lock)
        enter("5678", into: turnOff.type)
        XCTAssertTrue(turnOff.isDone)
        XCTAssertEqual(lock.mode, .off)
    }

    // MARK: - Settings

    func testTurningOnFaceIDChecksItFirst() async throws {
        try lock.setPasscode("1234")
        let settings = LockSettingsViewModel(lock: lock, owner: owner)
        owner.biometricsSucceed = false
        await settings.setBiometricsOn(true)
        XCTAssertFalse(settings.isBiometricsOn)

        owner.biometricsSucceed = true
        await settings.setBiometricsOn(true)
        XCTAssertTrue(settings.isBiometricsOn)
        await settings.setBiometricsOn(false)
        XCTAssertFalse(settings.isBiometricsOn)
        XCTAssertEqual(owner.biometricRequests, 2)
    }

    func testPasscodeSwitchOpensTheMatchingFlowAndReportsTheResult() throws {
        let settings = LockSettingsViewModel(lock: lock, owner: owner)
        settings.setPasscodeOn(true)
        let flow = try XCTUnwrap(settings.flow)
        XCTAssertEqual(flow.purpose, .create)
        enter("1234", into: flow.type)
        enter("1234", into: flow.type)
        settings.flowClosed()
        XCTAssertTrue(settings.isPasscodeOn)
        XCTAssertEqual(settings.notice, "암호 잠금을 켰어요.")

        settings.setPasscodeOn(false)
        XCTAssertEqual(settings.flow?.purpose, .turnOff)
        settings.flowClosed()
        XCTAssertTrue(settings.isPasscodeOn)
    }

    func testEarlierLockIsTurnedOffOnlyAfterTheOwnerConfirms() async {
        store.legacyBiometricsEnabled = true
        let settings = LockSettingsViewModel(lock: lock, owner: owner)
        owner.ownerSucceeds = false
        await settings.turnOffLegacyLock()
        XCTAssertTrue(settings.isLegacy)
        owner.ownerSucceeds = true
        await settings.turnOffLegacyLock()
        XCTAssertEqual(settings.mode, .off)
    }
}
