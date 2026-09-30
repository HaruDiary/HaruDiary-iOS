import Observation
import SafariServices
import SwiftUI
import UIKit

/// Shows the SwiftUI settings inside the tabs' navigation stacks, pushes the screens it opens and presents
/// sign-in and the Apple confirmation, which need a view controller. Remove when the tabs move to SwiftUI.
@MainActor
final class SettingsHostingController: UIHostingController<SettingsView> {
    private let module: SettingsModule
    private let values = SettingsRowValues()
    private let appleRequest = AppleAuthorizationRequest()
    private let calendar = Calendar.current

    init(module: SettingsModule) {
        self.module = module
        super.init(rootView: SettingsView(viewModel: module.viewModel, values: values, actions: .none))
        rootView = SettingsView(viewModel: module.viewModel, values: values, actions: SettingsActions(
            openReminders: { [weak self] in self?.push(ReminderModule.makeSettingsViewController()) },
            openLock: { [weak self] in self?.push(LockModule.makeSettingsViewController()) },
            openTrash: { [weak self] in
                guard let self else { return }
                self.push(self.module.makeTrashModule().makeViewController())
            },
            openWebPage: { [weak self] url in
                let safari = SFSafariViewController(url: url)
                safari.preferredControlTintColor = DiaryTheme.Colors.brandUIKit
                self?.present(safari, animated: true)
            },
            signIn: { [weak self] in
                guard let self else { return }
                self.present(SignInHostingController(gateway: self.module.signInGateway), animated: true)
            },
            confirmWithAppleThenDelete: { [weak self] in self?.confirmWithAppleThenDelete() },
            accountChanged: {
                // 여정 화면은 아직 이 알림으로 사용자 변경을 반영한다.
                NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
            }
        ))
        title = "설정"
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DiaryTheme.Colors.backgroundUIKit
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "설정", style: .plain, target: nil, action: nil)
        module.viewModel.start()
        observeDeletion()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DiaryTheme.Colors.brandUIKit
        refreshValues()
    }

    // Popping settings ends the account observation.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            module.viewModel.stop()
        }
    }

    /// Reminders and the lock are changed on the pushed screens, so their values are read again on return.
    private func refreshValues() {
        values.reminder = SettingsSummary.reminder(UserDefaultsReminderStore(calendar: calendar).settings, calendar: calendar)
        values.lock = SettingsSummary.lock(LockModule.makeLock().mode, biometry: LiveDeviceOwnerAuthenticator().biometry)
        let info = Bundle.main.infoDictionary
        values.version = SettingsSummary.version(short: info?["CFBundleShortVersionString"] as? String,
                                                 build: info?["CFBundleVersion"] as? String)
    }

    private func push(_ controller: UIViewController) {
        navigationController?.pushViewController(controller, animated: true)
    }

    /// No way back while the account is being deleted.
    private func observeDeletion() {
        withObservationTracking {
            navigationItem.hidesBackButton = module.viewModel.isDeletingAccount
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeDeletion() }
        }
    }

    // Apple 회원은 탈퇴 직전에 Apple로 한 번 더 확인한다. 이 확인으로 Firebase가 Apple 연결을 끊는다.
    private func confirmWithAppleThenDelete() {
        appleRequest.start(from: self) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let apple):
                Task { await self.module.viewModel.deleteAccount(appleAuthorization: apple) }
            case .failure(AppleAuthorizationRequest.Failure.canceled):
                break
            case .failure:
                let alert = UIAlertController(title: "Apple 확인 실패", message: "Apple 계정을 확인하지 못했어요.\n잠시 후 다시 시도해주세요.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(alert, animated: true)
            }
        }
    }
}

extension SettingsActions {
    /// Placeholder for the first `rootView`, replaced before the screen appears.
    static let none = SettingsActions(openReminders: {}, openLock: {}, openTrash: {}, openWebPage: { _ in }, signIn: {},
                                      confirmWithAppleThenDelete: {}, accountChanged: {})
}
