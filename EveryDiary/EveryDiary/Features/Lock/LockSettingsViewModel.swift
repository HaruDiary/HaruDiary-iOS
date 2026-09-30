import Foundation
import Observation

/// Settings › 잠금: the app passcode, changing it, and Face ID/Touch ID as an extra way to unlock.
@MainActor
@Observable
final class LockSettingsViewModel {
    private(set) var mode: AppLock.Mode
    /// The passcode sheet being shown, if any.
    var flow: PasscodeFlowViewModel?
    private(set) var notice: String?

    private let lock: AppLock
    private let owner: any DeviceOwnerAuthenticating

    init(lock: AppLock, owner: any DeviceOwnerAuthenticating) {
        self.lock = lock
        self.owner = owner
        mode = lock.mode
    }

    var isPasscodeOn: Bool {
        if case .passcode = mode { return true }
        return false
    }

    var isLegacy: Bool { mode == .legacyBiometrics }
    var isBiometricsOn: Bool { mode == .passcode(biometrics: true) }
    /// nil when this device cannot use Face ID/Touch ID for the app.
    var biometry: Biometry? { owner.biometry == .none ? nil : owner.biometry }
    var biometryName: String? { biometry?.name }

    func setPasscodeOn(_ on: Bool) {
        guard on != isPasscodeOn else { return }
        flow = PasscodeFlowViewModel(purpose: on ? .create : .turnOff, lock: lock)
    }

    func changePasscode() {
        guard isPasscodeOn else { return }
        flow = PasscodeFlowViewModel(purpose: .change, lock: lock)
    }

    /// The sheet closed, finished or cancelled.
    func flowClosed() {
        if let flow, flow.isDone {
            switch flow.purpose {
            case .create: notice = "암호 잠금을 켰어요."
            case .change: notice = "암호를 바꿨어요."
            case .turnOff: notice = "암호 잠금을 껐어요."
            }
        }
        flow = nil
        mode = lock.mode
    }

    /// Turning biometrics on asks for them once, so a face or finger that does not work is found now.
    func setBiometricsOn(_ on: Bool) async {
        guard isPasscodeOn, on != isBiometricsOn else { return }
        if on {
            guard let name = biometryName,
                  await owner.authenticateWithBiometrics(reason: "\(name)로 잠금을 해제할 수 있게 확인합니다.") else {
                mode = lock.mode
                return
            }
        }
        lock.setBiometrics(on)
        mode = lock.mode
    }

    /// The lock from an earlier version (biometrics only) is turned off here, after the owner confirms it the
    /// same way it unlocks; setting a passcode replaces it instead.
    func turnOffLegacyLock() async {
        guard isLegacy, await owner.authenticateDeviceOwner(reason: "잠금을 끄려면 본인을 확인해주세요.") else { return }
        do {
            try lock.turnOff()
            notice = "잠금을 껐어요."
        } catch {
            notice = "잠금을 끄지 못했어요. 다시 시도해주세요."
        }
        mode = lock.mode
    }

    func noticeShown() {
        notice = nil
    }
}
