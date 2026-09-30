import Foundation
import LocalAuthentication

/// The passcode record in the Keychain (this device only), the rest in UserDefaults.
final class LiveAppLockStore: AppLockStore {
    private static let passcodeKey = "appLockPasscode"
    private static let biometricsKey = "AppLockBiometricsEnabled"
    /// The switch of the earlier biometrics-only lock.
    private static let legacyKey = "BiometricsEnabled"
    private static let failedKey = "AppLockFailedAttempts"
    private static let lockedUntilKey = "AppLockLockedUntil"
    private static let installedKey = "AppLockInstalled"

    private let secrets: any SecretStore
    private let defaults: UserDefaults

    init(secrets: any SecretStore = KeychainSecretStore(), defaults: UserDefaults = .standard) {
        self.secrets = secrets
        self.defaults = defaults
        // Keychain items outlive deleting the app, UserDefaults do not: a reinstalled app starts unlocked.
        if !defaults.bool(forKey: Self.installedKey) {
            secrets.remove(Self.passcodeKey)
            defaults.set(true, forKey: Self.installedKey)
        }
    }

    var passcodeRecord: String? {
        secrets.string(for: Self.passcodeKey)
    }

    func savePasscodeRecord(_ record: String?) throws {
        guard let record else {
            secrets.remove(Self.passcodeKey)
            // `remove` does not report failures; an item still there means the Keychain refused.
            guard secrets.string(for: Self.passcodeKey) == nil else {
                print("App lock passcode not deleted")
                throw CocoaError(.fileWriteNoPermission)
            }
            return
        }
        do {
            try secrets.set(record, for: Self.passcodeKey)
        } catch {
            print("App lock passcode not saved: \((error as NSError).code)")
            throw error
        }
    }

    var biometricsEnabled: Bool {
        get { defaults.bool(forKey: Self.biometricsKey) }
        set { defaults.set(newValue, forKey: Self.biometricsKey) }
    }

    var legacyBiometricsEnabled: Bool {
        get { defaults.bool(forKey: Self.legacyKey) }
        set { defaults.set(newValue, forKey: Self.legacyKey) }
    }

    var failedAttempts: Int {
        get { defaults.integer(forKey: Self.failedKey) }
        set { defaults.set(newValue, forKey: Self.failedKey) }
    }

    var lockedUntil: Date? {
        get { defaults.object(forKey: Self.lockedUntilKey) as? Date }
        set { defaults.set(newValue, forKey: Self.lockedUntilKey) }
    }
}

@MainActor
final class LiveDeviceOwnerAuthenticator: DeviceOwnerAuthenticating {
    var biometry: Biometry {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return .none }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    func authenticateWithBiometrics(reason: String) async -> Bool {
        let context = LAContext()
        // No "Enter Password" button: the app passcode on the lock screen is the fallback.
        context.localizedFallbackTitle = ""
        return await evaluate(.deviceOwnerAuthenticationWithBiometrics, context: context, reason: reason)
    }

    func authenticateDeviceOwner(reason: String) async -> Bool {
        await evaluate(.deviceOwnerAuthentication, context: LAContext(), reason: reason)
    }

    private func evaluate(_ policy: LAPolicy, context: LAContext, reason: String) async -> Bool {
        do {
            return try await context.evaluatePolicy(policy, localizedReason: reason)
        } catch {
            // Cancelled or not available; the code only, to find the cause.
            print("Device owner authentication failed: \((error as NSError).code)")
            return false
        }
    }
}
