//
//  LoginVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/28/24.
//

import UIKit

import SnapKit
import FirebaseAuth
import Firebase
import GoogleSignIn

class LoginVC: UIViewController {
    
    private let gateway: any SocialSignInGateway
    private let appleRequest = AppleAuthorizationRequest()
    private var isSigningIn = false {
        didSet {
            signGoogleButton.isEnabled = !isSigningIn
            signAppleButton.isEnabled = !isSigningIn
            isSigningIn ? progress.startAnimating() : progress.stopAnimating()
        }
    }
    
    init(gateway: any SocialSignInGateway) {
        self.gateway = gateway
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { return nil }
    
    private let progress: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var topLabel : UILabel = {
        let label = UILabel()
        label.text = "마음 놓고"
        label.font = UIFont(name: "SFProDisplay-Bold", size: 50)
        label.textAlignment = .left
        label.textColor = UIColor(named: "mainCell")
        return label
    }()
    
    private lazy var bottomLabel : UILabel = {
        let label = UILabel()
        label.text = "일기 쓰자"
        label.font = UIFont(name: "SFProDisplay-Bold", size: 50)
        label.textAlignment = .left
        label.textColor = UIColor(named: "subBackground")
        return label
    }()
    
    private lazy var signGoogleButton : UIButton = {
        let signGoogleButton = UIButton()
        signGoogleButton.setImage(.signInGoogle, for: .normal)
        signGoogleButton.addTarget(self, action: #selector(tapGoogleLoginButton), for: .touchUpInside)
        return signGoogleButton
    }()
    
    private lazy var signAppleButton : UIButton = {
        let signAppleButton = UIButton()
        signAppleButton.setImage(.signinApple, for: .normal)
        signAppleButton.addTarget(self, action: #selector(tapAppleLoginButton), for: .touchUpInside)
        return signAppleButton
    }()
    
    private lazy var closeButton : UIButton = {
        let closeButton = UIButton()
        closeButton.setImage(UIImage(systemName:"xmark"), for: .normal)
        closeButton.sizeToFit()
        closeButton.tintColor = .mainCell
        closeButton.addTarget(self, action: #selector(tapCloseButton), for: .touchUpInside)
        return closeButton
    }()
    
    @objc func tapAppleLoginButton() {
        startSignInWithAppleFlow()
    }
    
    @objc func tapGoogleLoginButton() {
        handleGIDSignIn()
    }
    
    @objc func tapCloseButton() {
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: - Google로 로그인 및 Firebase 인증
    private func handleGIDSignIn() {
        guard !isSigningIn, let clientID = FirebaseApp.app()?.options.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        isSigningIn = true
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] signInResult, error in
            guard let self else { return }
            if let error {
                self.isSigningIn = false
                // 사용자가 직접 닫은 경우는 알리지 않는다.
                if (error as NSError).code != GIDSignInError.canceled.rawValue {
                    self.showSignInFailure(error)
                }
                return
            }
            guard let user = signInResult?.user, let idToken = user.idToken?.tokenString else {
                self.isSigningIn = false
                self.showSignInFailure(nil)
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            self.completeSignIn(SocialCredential(provider: .google, raw: credential), displayName: user.profile?.name)
        }
    }
    
    // 계정 연결·전환 규칙은 SocialSignIn이 정한다. 화면은 결과만 표시한다.
    private func completeSignIn(_ credential: SocialCredential, displayName: String?) {
        isSigningIn = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let outcome = try await SocialSignIn.run(with: credential, displayName: displayName, gateway: self.gateway)
                // 여정 화면과 설정의 표시 이름 갱신은 아직 이 알림을 사용한다.
                NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
                if outcome.asksForNickname(currentName: self.gateway.currentName) {
                    self.isSigningIn = false
                    self.askForNickname(message: "일기에서 불릴 이름을 정해주세요.\n설정에서 언제든 바꿀 수 있어요.")
                } else {
                    self.dismiss(animated: true, completion: nil)
                }
            } catch {
                self.isSigningIn = false
                self.showSignInFailure(error)
            }
        }
    }
    
    // 손님에서 가입했거나 이름이 없는 계정은 로그인 직후 닉네임을 정한다. "나중에"를 누르면 그대로 닫는다.
    private func askForNickname(message: String) {
        let alert = NicknameAlert.make(title: "닉네임 설정", message: message, current: gateway.currentName,
                                       cancelTitle: "나중에", onSave: { [weak self] text in self?.saveNickname(text) },
                                       onCancel: { [weak self] in self?.dismiss(animated: true) })
        present(alert, animated: true)
    }
    
    private func saveNickname(_ text: String) {
        let name: String
        do {
            name = try Nickname.validated(text)
        } catch let problem as Nickname.Problem {
            askForNickname(message: NicknameAlert.problemMessage(problem))
            return
        } catch {
            return
        }
        isSigningIn = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.gateway.updateDisplayName(name)
                NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
                self.dismiss(animated: true)
            } catch {
                self.isSigningIn = false
                let alert = UIAlertController(title: "닉네임 저장 실패", message: "로그인은 완료되었어요.\n닉네임은 설정에서 다시 정할 수 있어요.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in self?.dismiss(animated: true) })
                self.present(alert, animated: true)
            }
        }
    }
    
    // 원인을 찾을 수 있도록 오류 코드만 표시·기록한다. 토큰과 이메일은 남기지 않는다.
    private func showSignInFailure(_ error: Error?) {
        let nsError = error.map { $0 as NSError }
        let code = nsError.map { "\n(오류: \($0.domain) \($0.code))" } ?? ""
        print("Sign-in failed\(code.replacingOccurrences(of: "\n", with: " "))")
        let alert = UIAlertController(title: "로그인하지 못했어요", message: Self.failureMessage(for: nsError) + code, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private static func failureMessage(for error: NSError?) -> String {
        guard let error, error.domain == AuthErrorDomain else { return "잠시 후 다시 시도해주세요." }
        switch AuthErrorCode(rawValue: error.code) {
        case .accountExistsWithDifferentCredential:
            // 같은 이메일의 Google·Apple 계정은 하나만 만들 수 있다.
            return "같은 이메일로 다른 로그인 방식(Google 또는 Apple)의 계정이 있어요.\n그 방식으로 로그인해주세요."
        case .networkError:
            return "네트워크 연결을 확인한 뒤 다시 시도해주세요."
        case .userDisabled:
            return "사용이 중지된 계정이에요."
        default:
            return "잠시 후 다시 시도해주세요."
        }
    }
}

// MARK: - Views & Layouts
extension LoginVC {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSubViewsLoginVC()
        autoLayoutLoginVC()
    }
    
    private func addSubViewsLoginVC() {
        view.addSubview(signGoogleButton)
        view.addSubview(signAppleButton)
        view.addSubview(closeButton)
        view.addSubview(topLabel)
        view.addSubview(bottomLabel)
        view.addSubview(progress)
        view.backgroundColor = .loginBackground
    }
    
    private func autoLayoutLoginVC() {
        progress.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.right.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.width.height.equalTo(25)
        }
        closeButton.imageView?.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        signGoogleButton.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.width.equalTo(view.safeAreaLayoutGuide).offset(-50)
            make.height.equalTo(60)
        }
        signAppleButton.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.top.equalTo(signGoogleButton.snp.bottom).offset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(50)
            make.width.equalTo(view.safeAreaLayoutGuide).offset(-50)
            make.height.equalTo(60)
        }
        topLabel.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.width.equalTo(view.safeAreaLayoutGuide).offset(-50)
        }
        bottomLabel.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.centerY.equalTo(view.safeAreaLayoutGuide).offset(-120)
            make.width.equalTo(view.safeAreaLayoutGuide).offset(-100)
            make.top.equalTo(topLabel.snp.bottom).offset(5)
        }
    }
}

// MARK: - Apple로 로그인 및 Firebase 인증
extension LoginVC {
    private func startSignInWithAppleFlow() {
        guard !isSigningIn else { return }
        appleRequest.start(from: self) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let apple):
                // Apple 로그인 사용 여부 확인에 쓰는 Apple 사용자 ID를 보관한다.
                self.gateway.rememberAppleUserID(apple.appleUserID)
                self.completeSignIn(self.gateway.appleCredential(for: apple), displayName: apple.displayName)
            case .failure(AppleAuthorizationRequest.Failure.canceled):
                break
            case .failure(let error):
                self.showSignInFailure(error)
            }
        }
    }
}
