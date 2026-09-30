import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI
import UIKit

/// Presents the SwiftUI sign-in screen from UIKit settings and opens the Google and Apple sheets, which need a
/// presenting view controller. Remove this bridge when settings move to SwiftUI.
@MainActor
final class SignInHostingController: UIHostingController<SignInView> {
    private let viewModel: SignInViewModel
    private let gateway: any SocialSignInGateway
    private let appleRequest = AppleAuthorizationRequest()

    init(gateway: any SocialSignInGateway) {
        // 여정 화면과 설정의 표시 이름 갱신은 아직 이 알림을 사용한다.
        let viewModel = SignInViewModel(gateway: gateway, onAccountChanged: {
            NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
        })
        self.viewModel = viewModel
        self.gateway = gateway
        super.init(rootView: SignInView(viewModel: viewModel, onApple: {}, onGoogle: {}, onFinish: {}))
        rootView = SignInView(viewModel: viewModel,
                              onApple: { [weak self] in self?.signInWithApple() },
                              onGoogle: { [weak self] in self?.signInWithGoogle() },
                              onFinish: { [weak self] in self?.dismiss(animated: true) })
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { return nil }

    // MARK: - Google로 로그인
    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID, viewModel.beginProvider() else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        Task {
            do {
                finishGoogle(try await GIDSignIn.sharedInstance.signIn(withPresenting: self), error: nil)
            } catch {
                finishGoogle(nil, error: error)
            }
        }
    }

    private func finishGoogle(_ signInResult: GIDSignInResult?, error: Error?) {
        if let error {
            // 사용자가 직접 닫은 경우는 알리지 않는다.
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                viewModel.providerCancelled()
            } else {
                viewModel.providerFailed(error)
            }
            return
        }
        guard let user = signInResult?.user, let idToken = user.idToken?.tokenString else {
            viewModel.providerFailed(nil)
            return
        }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
        Task {
            await viewModel.complete(with: SocialCredential(provider: .google, raw: credential),
                                          displayName: user.profile?.name)
        }
    }

    // MARK: - Apple로 로그인
    private func signInWithApple() {
        guard viewModel.beginProvider() else { return }
        appleRequest.start(from: self) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let apple):
                // Apple 로그인 사용 여부 확인에 쓰는 Apple 사용자 ID를 보관한다.
                self.gateway.rememberAppleUserID(apple.appleUserID)
                Task {
                    await self.viewModel.complete(with: self.gateway.appleCredential(for: apple),
                                                  displayName: apple.displayName)
                }
            case .failure(AppleAuthorizationRequest.Failure.canceled):
                self.viewModel.providerCancelled()
            case .failure(let error):
                self.viewModel.providerFailed(error)
            }
        }
    }
}
