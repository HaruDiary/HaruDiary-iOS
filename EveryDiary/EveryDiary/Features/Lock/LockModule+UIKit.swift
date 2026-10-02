import SwiftUI
import UIKit

/// Creates the lock from the live Keychain/UserDefaults store and LocalAuthentication. Every instance reads the
/// same stored state, so settings and the lock screen stay in step.
@MainActor
enum LockModule {
    static func makeLock() -> AppLock {
        AppLock(store: LiveAppLockStore())
    }

    static func makeSettingsViewModel() -> LockSettingsViewModel {
        LockSettingsViewModel(lock: makeLock(), owner: LiveDeviceOwnerAuthenticator())
    }
}

/// Covers the scene's window with the lock screen in a window of its own, so nothing below can be touched
/// or seen (also in the app switcher) until it is unlocked. The lock screen is SwiftUI; the window is UIKit,
/// because a SwiftUI overlay would not cover open sheets.
@MainActor
final class AppLockPresenter {
    private let makeLock: @MainActor () -> AppLock
    private let owner: any DeviceOwnerAuthenticating
    private weak var mainWindow: UIWindow?
    private var lockWindow: UIWindow?
    private var screen: LockScreenViewModel?
    /// Gives the lock screen's window the app's text size, and keeps it up to date while the lock is shown.
    /// Gives the lock screen's window the app's text size and light or dark appearance.
    var configureWindow: ((UIWindow) -> Void)?
    /// The passcode was forgotten and the lock was turned off after the device owner was confirmed.
    var onTurnedOff: (() -> Void)?
    /// After the earlier biometrics-only lock: invite the user to set the app passcode that replaces it.
    var onAskForPasscode: (() -> Void)?

    init(makeLock: @escaping @MainActor () -> AppLock, owner: any DeviceOwnerAuthenticating) {
        self.makeLock = makeLock
        self.owner = owner
    }

    static func live() -> AppLockPresenter {
        AppLockPresenter(makeLock: LockModule.makeLock, owner: LiveDeviceOwnerAuthenticator())
    }

    var isLockEnabled: Bool { makeLock().isEnabled }
    var isLocked: Bool { lockWindow != nil }

    func attach(to window: UIWindow) {
        mainWindow = window
    }

    /// At launch and when the app goes to the background.
    func lockIfNeeded() {
        guard lockWindow == nil, let scene = mainWindow?.windowScene else { return }
        let lock = makeLock()
        guard lock.isEnabled else { return }
        let model = LockScreenViewModel(lock: lock, owner: owner)
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        configureWindow?(window)
        window.rootViewController = UIHostingController(rootView: LockScreenView(viewModel: model))
        window.makeKeyAndVisible()
        lockWindow = window
        screen = model
        observe(model)
    }

    /// Face ID cannot be asked for in the background, so it waits until the scene is active.
    func didBecomeActive() {
        guard let screen else { return }
        Task { await screen.promptBiometricsOnce() }
    }

    private func observe(_ model: LockScreenViewModel) {
        withObservationTracking {
            _ = model.outcome
        } onChange: { [weak self] in
            Task { @MainActor in self?.outcomeChanged(model) }
        }
    }

    private func outcomeChanged(_ model: LockScreenViewModel) {
        guard model === screen else { return }
        guard let outcome = model.outcome else { return observe(model) }
        let window = lockWindow
        lockWindow = nil
        screen = nil
        mainWindow?.makeKey()
        UIView.animate(withDuration: 0.2, animations: { window?.alpha = 0 }, completion: { _ in window?.isHidden = true })
        switch outcome {
        case .unlocked:
            break
        case .unlockedAndTurnedOff:
            onTurnedOff?()
        case .unlockedAskingForPasscode:
            onAskForPasscode?()
        }
    }
}
