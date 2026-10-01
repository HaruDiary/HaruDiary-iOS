import AuthenticationServices
import CryptoKit
import SwiftUI

/// A Sign in with Apple request and the reading of Apple's answer. The sheet itself is shown by SwiftUI's
/// `authorizationController`. Used for signing in and for confirming the account again before a withdrawal.
struct AppleSignInRequest {
    enum Failure: Error {
        case canceled
        case invalidResponse
    }

    let request: ASAuthorizationAppleIDRequest
    /// Each nonce is used once.
    let rawNonce: String

    init?() {
        guard let nonce = Self.randomNonce() else { return nil }
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        // Apple returns the SHA-256 of the nonce in the token; Firebase checks it against the raw value (replay protection).
        request.nonce = Self.sha256(nonce)
        self.request = request
        rawNonce = nonce
    }

    @MainActor
    func perform(with controller: AuthorizationController) async throws -> AppleAuthorization {
        let result: ASAuthorizationResult
        do {
            result = try await controller.performRequest(request)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            throw Failure.canceled
        }
        guard case .appleID(let credential) = result,
              let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
            throw Failure.invalidResponse
        }
        return AppleAuthorization(
            identityToken: token, rawNonce: rawNonce,
            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
            appleUserID: credential.user, fullName: credential.fullName
        )
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
