import AuthenticationServices
import SwiftUI

/// Settings inside a tab's navigation stack: the rows push their screens, sign-in and web pages open over it.
struct SettingsScreen: View {
    let shell: AppShell
    /// The tab whose navigation stack holds this screen.
    let tab: Int
    @State private var module: Once<SettingsModule>
    @State private var values = SettingsRowValues()
    @State private var webPage: WebPage?
    @State private var appleConfirmationFailed = false
    @Environment(\.authorizationController) private var authorizationController

    private let calendar = Calendar.current

    init(shell: AppShell, tab: Int, makeModule: @escaping @MainActor () -> SettingsModule) {
        self.shell = shell
        self.tab = tab
        _module = State(initialValue: Once(makeModule))
    }

    private var viewModel: SettingsViewModel { module.value.viewModel }

    var body: some View {
        SettingsView(viewModel: viewModel, values: values, actions: SettingsActions(
            openReminders: { shell.push(.reminders) },
            openLock: { shell.push(.lock) },
            openTextSize: { shell.push(.textSize) },
            openTrash: { shell.push(.trash) },
            openWebPage: { webPage = WebPage(url: $0) },
            signIn: { shell.isSigningIn = true },
            confirmWithAppleThenDelete: { Task { await confirmWithAppleThenDelete() } },
            accountChanged: {
                // The account session refreshes the signed-in user on this notification.
                NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
            }
        ), profilePhotos: module.value.profilePhotos)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        // No way back while the account is being deleted.
        .navigationBarBackButtonHidden(viewModel.isDeletingAccount)
        .onAppear {
            viewModel.start()
            // Reminders, the lock and the text size are changed on the pushed screens, so they are read again on return.
            refreshValues()
        }
        .onDisappear {
            // Leaving settings ends the account observation; opening a screen from it does not.
            if !shell.isShowing(.settings, inTab: tab) { viewModel.stop() }
        }
        .sheet(item: $webPage) { page in
            SafariView(url: page.url).ignoresSafeArea()
        }
        .alert("Apple 확인 실패", isPresented: $appleConfirmationFailed) {
            Button("확인") {}
        } message: {
            Text("Apple 계정을 확인하지 못했어요.\n잠시 후 다시 시도해주세요.")
        }
    }

    private func refreshValues() {
        values.reminder = SettingsSummary.reminder(UserDefaultsReminderStore(calendar: calendar).settings, calendar: calendar)
        values.lock = SettingsSummary.lock(LockModule.makeLock().mode, biometry: LiveDeviceOwnerAuthenticator().biometry)
        values.textSize = module.value.textSize?.setting.title ?? AppTextSize.system.title
        let info = Bundle.main.infoDictionary
        values.version = SettingsSummary.version(short: info?["CFBundleShortVersionString"] as? String,
                                                 build: info?["CFBundleVersion"] as? String)
    }

    /// Apple members confirm with Apple once more right before the withdrawal; Firebase then unlinks Apple.
    private func confirmWithAppleThenDelete() async {
        guard let request = AppleSignInRequest() else { return }
        do {
            let apple = try await request.perform(with: authorizationController)
            await viewModel.deleteAccount(appleAuthorization: apple)
        } catch AppleSignInRequest.Failure.canceled {
            return
        } catch {
            appleConfirmationFailed = true
        }
    }
}
