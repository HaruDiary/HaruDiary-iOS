import CryptoKit
import Foundation
import Security

/// Where the app lock keeps its state. The passcode record belongs in the Keychain; the rest may live in
/// UserDefaults, which also keeps a wrong-passcode wait across relaunches.
protocol AppLockStore: AnyObject {
    /// "salt:hash" of the passcode, both base64. nil when no passcode is set.
    var passcodeRecord: String? { get }
    /// Saves or (with nil) removes the record; throws when the Keychain refuses, so no one is told it was set.
    func savePasscodeRecord(_ record: String?) throws
    var biometricsEnabled: Bool { get set }
    /// Earlier versions locked with Face ID/Touch ID (falling back to the iPhone passcode) and had no app passcode.
    var legacyBiometricsEnabled: Bool { get set }
    var failedAttempts: Int { get set }
    var lockedUntil: Date? { get set }
}

/// The app's own 4-digit passcode lock, with Face ID/Touch ID as an optional faster way in.
@MainActor
final class AppLock {
    static let passcodeLength = 4

    enum Mode: Equatable {
        case off
        case passcode(biometrics: Bool)
        /// Set up by an earlier version: unlock with biometrics or the iPhone passcode, then set an app passcode.
        case legacyBiometrics
    }

    enum Attempt: Equatable {
        case unlocked
        /// Wrong passcode; `triesBeforeWait` more wrong entries start a wait.
        case wrong(triesBeforeWait: Int)
        case wait(until: Date)
    }

    private let store: any AppLockStore
    private let now: () -> Date

    init(store: any AppLockStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    var mode: Mode {
        if store.passcodeRecord != nil { return .passcode(biometrics: store.biometricsEnabled) }
        return store.legacyBiometricsEnabled ? .legacyBiometrics : .off
    }

    var isEnabled: Bool { mode != .off }

    /// When a wait after too many wrong passcodes ends; nil when the passcode can be entered now.
    var waitUntil: Date? {
        guard let until = store.lockedUntil, until > now() else { return nil }
        return until
    }

    static func isValid(_ passcode: String) -> Bool {
        passcode.count == passcodeLength && passcode.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Sets or replaces the passcode. Someone moving from the old biometrics lock keeps biometrics on.
    /// Throws when it could not be saved; the previous passcode (or none) then stays in effect.
    func setPasscode(_ passcode: String) throws {
        precondition(Self.isValid(passcode))
        var salt = Data(count: 16)
        salt.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        try store.savePasscodeRecord(salt.base64EncodedString() + ":" + Self.hash(passcode, salt: salt).base64EncodedString())
        if store.legacyBiometricsEnabled {
            store.biometricsEnabled = true
            store.legacyBiometricsEnabled = false
        }
        resetAttempts()
    }

    /// Checks a passcode without unlocking or counting it, for confirming the current passcode in settings.
    func matches(_ passcode: String) -> Bool {
        guard let record = store.passcodeRecord else { return false }
        let parts = record.split(separator: ":").map(String.init)
        guard parts.count == 2, let salt = Data(base64Encoded: parts[0]), let hash = Data(base64Encoded: parts[1]) else {
            return false
        }
        return Self.hash(passcode, salt: salt) == hash
    }

    /// Unlocking with the passcode. Wrong entries are counted across relaunches.
    func unlock(with passcode: String) -> Attempt {
        if let until = waitUntil { return .wait(until: until) }
        if matches(passcode) {
            resetAttempts()
            return .unlocked
        }
        store.failedAttempts += 1
        if let wait = Self.wait(afterFailures: store.failedAttempts) {
            let until = now().addingTimeInterval(wait)
            store.lockedUntil = until
            return .wait(until: until)
        }
        return .wrong(triesBeforeWait: Self.freeAttempts - store.failedAttempts)
    }

    /// Face ID/Touch ID, or the iPhone passcode, already confirmed the owner.
    func unlockedByDeviceOwner() {
        resetAttempts()
    }

    func setBiometrics(_ enabled: Bool) {
        guard store.passcodeRecord != nil else { return }
        store.biometricsEnabled = enabled
    }

    /// Turns the lock off, e.g. after the passcode was forgotten and the iPhone passcode confirmed the owner.
    /// Throws when the passcode could not be deleted; the lock then stays as it was.
    func turnOff() throws {
        try store.savePasscodeRecord(nil)
        store.biometricsEnabled = false
        store.legacyBiometricsEnabled = false
        resetAttempts()
    }

    // MARK: - Policy

    /// Wrong entries allowed before the first wait.
    static let freeAttempts = 5

    /// 5th wrong entry: 30 s, 6th: 1 min, 7th: 5 min, then 15 min each.
    static func wait(afterFailures failures: Int) -> TimeInterval? {
        switch failures {
        case ..<freeAttempts: return nil
        case freeAttempts: return 30
        case freeAttempts + 1: return 60
        case freeAttempts + 2: return 5 * 60
        default: return 15 * 60
        }
    }

    private func resetAttempts() {
        store.failedAttempts = 0
        store.lockedUntil = nil
    }

    private static func hash(_ passcode: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(passcode.utf8)))
    }
}
