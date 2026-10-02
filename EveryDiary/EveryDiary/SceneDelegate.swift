//
//  SceneDelegate.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import FirebaseAuth
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    var blurEffectView: UIVisualEffectView?
    private lazy var appLock = AppLockPresenter.live()
    private var reminders: DiaryReminders?
    private var profilePhotoKeeper: ProfilePhotoKeeper?
    private var widgetUpdater: DiaryWidgetUpdater?
    private var userDirectoryUpdater: UserDirectoryUpdater?
    // Created after FirebaseApp.configure() in AppDelegate.
    private lazy var appleCredentialMonitor = AppleCredentialMonitor(
        auth: .auth(),
        appleRecords: AppleSignInRecords(secrets: AppleSignInSecrets(secrets: KeychainSecretStore(), legacy: .standard))
    )
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        var live = AppDependencies.live()
        // One reminders instance for the whole app, also used by the reminder settings screen.
        let reminders = live.makeDiaryReminders()
        live.reminders = reminders
        self.reminders = reminders
        // Follows the account for as long as the app runs, also while settings are closed.
        profilePhotoKeeper = live.makeProfilePhotoKeeper()
        profilePhotoKeeper?.start()
        // The home screen widget shows the days written; it is told whenever they change.
        widgetUpdater = live.makeDiaryWidgetUpdater()
        widgetUpdater?.start()
        // The account's support code, nickname and sign-in method, kept next to its diaries.
        userDirectoryUpdater = live.makeUserDirectoryUpdater()
        userDirectoryUpdater?.start()
        let textSize = AppTextSizeController(store: UserDefaultsTextSizeStore())
        live.textSize = textSize
        let appearance = AppAppearanceController(store: UserDefaultsAppearanceStore())
        live.appearance = appearance

        // Every screen is SwiftUI; this window only hosts the root view.
        let shell = AppShell()
        let root = UIHostingController(rootView: AppRootView(shell: shell, dependencies: live))
        root.view.backgroundColor = DiaryTheme.Colors.backgroundUIKit
        window.rootViewController = root
        // SwiftUI sheets, covers and alerts are presented from the root; messages wait until they close.
        shell.isCoveredByPresentedScreen = { [weak root] in root?.presentedViewController != nil }
        appearance.attach(to: window)
        textSize.attach(to: window)
        window.makeKeyAndVisible()

        appLock.configureWindow = { [weak textSize, weak appearance] in
            textSize?.attach(to: $0)
            appearance?.attach(to: $0)
        }
        appLock.onTurnedOff = { [weak shell] in
            shell?.announce("앱 잠금을 껐어요", message: "설정 › 잠금에서 새 암호를 정할 수 있어요.", duration: 2.5)
        }
        appLock.onAskForPasscode = { [weak shell] in shell?.invitePasscodeSetup() }
        appLock.attach(to: window)
        appLock.lockIfNeeded()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // The account listener must not outlive the scene; a reconnected scene starts its own.
        profilePhotoKeeper?.stop()
        profilePhotoKeeper = nil
        widgetUpdater?.stop()
        widgetUpdater = nil
        userDirectoryUpdater?.stop()
        userDirectoryUpdater = nil
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        removeBlurEffect()
        appleCredentialMonitor.check()
        appLock.didBecomeActive()
        // Moves the reminder window forward and brings back today's reminder after midnight.
        if let reminders { Task { await reminders.refresh() } }
    }
    
    // Hides the diary in the app switcher while the lock is on; the lock itself appears on entering the background.
    func sceneWillResignActive(_ scene: UIScene) {
        if appLock.isLockEnabled && !appLock.isLocked {
            addBlurEffect()
        }
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        appLock.lockIfNeeded()
    }
}

//MARK: - Blur Effect 메서드
extension SceneDelegate {
    private func addBlurEffect() {
        guard let window = window, blurEffectView == nil else { return }
        
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView?.frame = window.bounds
        blurEffectView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        window.addSubview(blurEffectView!)
    }

    private func removeBlurEffect() {
        blurEffectView?.removeFromSuperview()
        blurEffectView = nil
    }
}
