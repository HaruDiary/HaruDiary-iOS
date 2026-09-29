import AuthenticationServices
import CryptoKit
import UIKit

/// Shows the Sign in with Apple sheet and returns what Apple answered.
/// Used for signing in and for confirming the account again right before a withdrawal.
@MainActor
final class AppleAuthorizationRequest: NSObject {
    enum Failure: Error {
        case canceled
        case invalidResponse
    }

    private var nonce: String?
    private weak var anchor: UIViewController?
    private var completion: ((Result<AppleAuthorization, Error>) -> Void)?

    var isRunning: Bool { completion != nil }

    func start(from anchor: UIViewController, completion: @escaping (Result<AppleAuthorization, Error>) -> Void) {
        guard !isRunning, let nonce = Self.randomNonce() else { return }
        self.nonce = nonce
        self.anchor = anchor
        self.completion = completion
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        // Apple returns the SHA-256 of the nonce in the token; Firebase checks it against the raw value (replay protection).
        request.nonce = Self.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func finish(_ result: Result<AppleAuthorization, Error>) {
        let completion = completion
        // Each nonce is used once.
        self.completion = nil
        nonce = nil
        completion?(result)
    }

    private static func randomNonce(length: Int = 32) -> String? {
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        // 64 characters, so every byte maps evenly.
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleAuthorizationRequest: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { anchor?.view.window ?? ASPresentationAnchor() }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated {
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce, let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                finish(.failure(Failure.invalidResponse))
                return
            }
            finish(.success(AppleAuthorization(
                identityToken: token, rawNonce: nonce,
                authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
                appleUserID: credential.user, fullName: credential.fullName
            )))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated {
            finish(.failure((error as? ASAuthorizationError)?.code == .canceled ? Failure.canceled : error))
        }
    }
}
