import Foundation
import Observation

/// The screen that covers the app until it is unlocked: the app passcode, Face ID/Touch ID when turned on,
/// or the iPhone passcode when the app passcode is forgotten.
@MainActor
@Observable
final class LockScreenViewModel {
    enum Outcome: Equatable {
        case unlocked
        /// The earlier biometrics-only lock was unlocked; the app passcode is not set yet.
        case unlockedAskingForPasscode
        /// The passcode was forgotten, the iPhone passcode confirmed the owner and the lock is now off.
        case unlockedAndTurnedOff
    }

    private(set) var digits = ""
    private(set) var message: String?
    private(set) var mistakes = 0
    private(set) var isAuthenticating = false
    private(set) var outcome: Outcome?

    private let lock: AppLock
    private let owner: any DeviceOwnerAuthenticating
    private var promptedBiometrics = false

    init(lock: AppLock, owner: any DeviceOwnerAuthenticating) {
        self.lock = lock
        self.owner = owner
    }

    var isLegacy: Bool { lock.mode == .legacyBiometrics }
    var waitUntil: Date? { lock.waitUntil }

    /// Face ID/Touch ID when they unlock this lock and the device can use them.
    var biometry: Biometry? {
        guard lock.mode == .passcode(biometrics: true), owner.biometry != .none else { return nil }
        return owner.biometry
    }

    var biometryName: String? { biometry?.name }

    func type(_ digit: Int) {
        guard (0...9).contains(digit), digits.count < AppLock.passcodeLength, outcome == nil, waitUntil == nil else {
            return
        }
        digits += String(digit)
        guard digits.count == AppLock.passcodeLength else { return }
        let entered = digits
        digits = ""
        switch lock.unlock(with: entered) {
        case .unlocked:
            message = nil
            outcome = .unlocked
        case .wrong(let tries):
            mistakes += 1
            message = LockMessages.wrong(triesBeforeWait: tries)
        case .wait:
            mistakes += 1
            message = LockMessages.waiting
        }
    }

    func deleteLast() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }

    /// Asks for Face ID/Touch ID once each time the lock appears, when the app is active.
    func promptBiometricsOnce() async {
        guard !promptedBiometrics, outcome == nil else { return }
        promptedBiometrics = true
        if isLegacy {
            await unlockAsDeviceOwner()
        } else if biometryName != nil {
            await useBiometrics()
        }
    }

    func useBiometrics() async {
        guard !isAuthenticating, outcome == nil, let name = biometryName else { return }
        isAuthenticating = true
        let succeeded = await owner.authenticateWithBiometrics(reason: "\(name)로 하루일기 잠금을 해제합니다.")
        isAuthenticating = false
        guard succeeded, outcome == nil else { return }
        lock.unlockedByDeviceOwner()
        message = nil
        outcome = .unlocked
    }

    /// The earlier lock: Face ID/Touch ID, or the iPhone passcode, as before.
    func unlockAsDeviceOwner() async {
        guard !isAuthenticating, outcome == nil else { return }
        isAuthenticating = true
        let succeeded = await owner.authenticateDeviceOwner(reason: "하루일기 잠금을 해제합니다.")
        isAuthenticating = false
        guard succeeded, outcome == nil else { return }
        lock.unlockedByDeviceOwner()
        outcome = .unlockedAskingForPasscode
    }

    func forgotPasscode() async {
        guard !isAuthenticating, outcome == nil else { return }
        isAuthenticating = true
        let succeeded = await owner.authenticateDeviceOwner(reason: "iPhone 암호로 본인을 확인하면 앱 잠금을 끄고 새 암호를 정할 수 있어요.")
        isAuthenticating = false
        guard succeeded, outcome == nil else { return }
        lock.turnOff()
        outcome = .unlockedAndTurnedOff
    }
}
