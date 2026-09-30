//
//  SceneDelegate.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import FirebaseAuth
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    var blurEffectView: UIVisualEffectView?
    private lazy var appLock = AppLockPresenter.live()
    // Created after FirebaseApp.configure() in AppDelegate.
    private lazy var appleCredentialMonitor = AppleCredentialMonitor(
        auth: .auth(),
        appleRecords: AppleSignInRecords(secrets: AppleSignInSecrets(secrets: KeychainSecretStore(), legacy: .standard))
    )
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
       
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        OnboardingModule.install(in: window) { TabBarController(dependencies: .live()) }
        //강제로 다크모드 해제
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        appLock.attach(to: window)
        appLock.lockIfNeeded()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        removeBlurEffect()
        appleCredentialMonitor.check()
        appLock.didBecomeActive()
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
        
        let blurEffect = UIBlurEffect(style: .light)
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
