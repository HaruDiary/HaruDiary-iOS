import Foundation

enum Biometry: Equatable {
    case none
    case faceID
    case touchID
    case opticID

    /// The name shown in the app, e.g. "Face ID로 잠금 해제". nil when the device has no biometrics.
    var name: String? {
        switch self {
        case .none: return nil
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        }
    }
}

/// Face ID/Touch ID and the iPhone passcode, kept apart from LocalAuthentication so lock screens can be tested.
@MainActor
protocol DeviceOwnerAuthenticating {
    /// The biometrics this device can use now; `.none` when not set up or not allowed.
    var biometry: Biometry { get }
    /// Face ID/Touch ID only. The app passcode is the fallback, so the iPhone passcode is not offered.
    func authenticateWithBiometrics(reason: String) async -> Bool
    /// Face ID/Touch ID or the iPhone passcode, to confirm the owner when the app passcode is forgotten.
    func authenticateDeviceOwner(reason: String) async -> Bool
}
