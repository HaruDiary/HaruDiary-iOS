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
    // Created after FirebaseApp.configure() in AppDelegate.
    private lazy var appleCredentialMonitor = AppleCredentialMonitor(
        auth: .auth(),
        appleTokens: AppleTokenRevocation(store: AppleRefreshTokenStore(secrets: KeychainSecretStore(), legacy: .standard))
    )
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
       
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        OnboardingModule.install(in: window) { TabBarController(dependencies: .live()) }
        //강제로 다크모드 해제
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        removeBlurEffect()
        appleCredentialMonitor.check()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        let biometricsEnabled = UserDefaults.standard.bool(forKey: "BiometricsEnabled")
        
        if biometricsEnabled {
            addBlurEffect()
        }
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        let biometricsEnabled = UserDefaults.standard.bool(forKey: "BiometricsEnabled")
        
        if biometricsEnabled {
            
            BiometricsAuth().authenticateWithBiometrics { success, error  in
                DispatchQueue.main.async {
                    if success {
                        print("성공")
                    } else {
                        print("login 실패")
                    }
                }
            }
        }
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        
    }
}

//MARK: - Blur Effect 메서드
extension SceneDelegate {
    private func addBlurEffect() {
        guard let window = window else { return }
        
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
