import SwiftUI
import UIKit

/// Creates the lock from the live Keychain/UserDefaults store and LocalAuthentication. Every instance reads the
/// same stored state, so settings and the lock screen stay in step.
@MainActor
enum LockModule {
    static func makeLock() -> AppLock {
        AppLock(store: LiveAppLockStore())
    }

    static func makeSettingsViewController() -> UIViewController {
        LockSettingsHostingController(viewModel: LockSettingsViewModel(lock: makeLock(), owner: LiveDeviceOwnerAuthenticator()))
    }
}

// Remove this UIKit bridge when settings move to SwiftUI.
@MainActor
final class LockSettingsHostingController: UIHostingController<LockSettingsView> {
    init(viewModel: LockSettingsViewModel) {
        super.init(rootView: LockSettingsView(viewModel: viewModel))
        title = "잠금"
    }

    required init?(coder: NSCoder) { return nil }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DiaryTheme.Colors.brandUIKit
    }
}

/// Covers the scene's window with the lock screen in a window of its own, so nothing below can be touched
/// or seen (also in the app switcher) until it is unlocked.
@MainActor
final class AppLockPresenter {
    private let makeLock: @MainActor () -> AppLock
    private let owner: any DeviceOwnerAuthenticating
    private weak var mainWindow: UIWindow?
    private var lockWindow: UIWindow?
    private var screen: LockScreenViewModel?
    /// Gives the lock screen's window the app's text size, and keeps it up to date while the lock is shown.
    var applyTextSize: ((UIWindow) -> Void)?

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
        window.overrideUserInterfaceStyle = .light
        applyTextSize?(window)
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
            TemporaryAlert.presentOnTopScreen(with: "앱 잠금을 껐어요",
                                              message: "설정 › 잠금에서 새 암호를 정할 수 있어요.", interval: 2.5)
        case .unlockedAskingForPasscode:
            askForPasscode()
        }
    }

    /// After the earlier biometrics-only lock: invite the user to set the app passcode that replaces it.
    private func askForPasscode() {
        guard var top = mainWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let alert = UIAlertController(title: "앱 암호를 정해주세요",
                                      message: "이제 하루일기는 앱 암호로 잠가요. 암호를 정하면 Face ID도 계속 쓸 수 있어요.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel))
        alert.addAction(UIAlertAction(title: "암호 정하기", style: .default) { [weak top] _ in
            let flow = PasscodeFlowViewModel(purpose: .create, lock: LockModule.makeLock())
            let sheet = UIHostingController(rootView: AnyView(EmptyView()))
            sheet.rootView = AnyView(PasscodeFlowView(viewModel: flow, onClose: { [weak sheet] in sheet?.dismiss(animated: true) }))
            sheet.isModalInPresentation = true
            top?.present(sheet, animated: true)
        })
        top.present(alert, animated: true)
    }
}
