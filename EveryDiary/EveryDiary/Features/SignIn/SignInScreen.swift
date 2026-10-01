import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import SwiftUI

/// The sign-in screen with its Apple and Google sheets.
struct SignInScreen: View {
    let gateway: any SocialSignInGateway
    @State private var model: Once<SignInViewModel>
    @Environment(\.authorizationController) private var authorizationController
    @Environment(\.dismiss) private var dismiss

    init(gateway: any SocialSignInGateway) {
        self.gateway = gateway
        _model = State(initialValue: Once {
            // The account session refreshes the signed-in user on this notification.
            SignInViewModel(gateway: gateway, onAccountChanged: {
                NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
            })
        })
    }

    private var viewModel: SignInViewModel { model.value }

    var body: some View {
        SignInView(viewModel: viewModel,
                   onApple: { Task { await signInWithApple() } },
                   onGoogle: { Task { await signInWithGoogle() } },
                   onFinish: { dismiss() })
            // Like onboarding, drawn for a light background.
            .preferredColorScheme(.light)
    }

    private func signInWithApple() async {
        guard let request = AppleSignInRequest(), viewModel.beginProvider() else { return }
        do {
            let apple = try await request.perform(with: authorizationController)
            // Kept to check later whether Sign in with Apple is still allowed for this app.
            gateway.rememberAppleUserID(apple.appleUserID)
            await viewModel.complete(with: gateway.appleCredential(for: apple), displayName: apple.displayName)
        } catch AppleSignInRequest.Failure.canceled {
            viewModel.providerCancelled()
        } catch {
            viewModel.providerFailed(error)
        }
    }

    private func signInWithGoogle() async {
        // Google's sheet is presented by UIKit; it needs the view controller on top.
        guard let clientID = FirebaseApp.app()?.options.clientID, let presenter = TopViewController.find(),
              viewModel.beginProvider() else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        do {
            let user = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter).user
            guard let idToken = user.idToken?.tokenString else {
                viewModel.providerFailed(nil)
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            await viewModel.complete(with: SocialCredential(provider: .google, raw: credential), displayName: user.profile?.name)
        } catch {
            // Closing the sheet is not reported as a failure.
            if (error as NSError).code == GIDSignInError.canceled.rawValue {
                viewModel.providerCancelled()
            } else {
                viewModel.providerFailed(error)
            }
        }
    }
}
