import Foundation
import Observation

/// What the sign-in screen shows. The Google and Apple sheets are opened by the hosting screen, which passes their
/// result here; which account is signed in or linked is decided by `SocialSignIn`.
@MainActor
@Observable
final class SignInViewModel {
    enum Prompt: Equatable {
        case failure(message: String)
        case nickname(message: String)
        case nicknameNotSaved

        var title: String {
            switch self {
            case .failure: return "로그인하지 못했어요"
            case .nickname: return "닉네임 설정"
            case .nicknameNotSaved: return "닉네임 저장 실패"
            }
        }

        var message: String {
            switch self {
            case .failure(let message), .nickname(let message): return message
            case .nicknameNotSaved: return "로그인은 완료되었어요.\n닉네임은 설정에서 다시 정할 수 있어요."
            }
        }
    }

    private(set) var isSigningIn = false
    /// True once the screen should close: signed in, or the user chose to go back.
    private(set) var isFinished = false
    var prompt: Prompt?
    var nicknameDraft = ""

    private let gateway: any SocialSignInGateway
    private let onAccountChanged: () -> Void

    /// `onAccountChanged` tells the rest of the app that the account or its name changed.
    init(gateway: any SocialSignInGateway, onAccountChanged: @escaping () -> Void) {
        self.gateway = gateway
        self.onAccountChanged = onAccountChanged
    }

    /// Call before opening the Google or Apple sheet. False while another sign-in is still running.
    func beginProvider() -> Bool {
        guard !isSigningIn, !isFinished else { return false }
        isSigningIn = true
        return true
    }

    /// The user closed the Google or Apple sheet; nothing to report.
    func providerCancelled() {
        isSigningIn = false
    }

    func providerFailed(_ error: Error?) {
        isSigningIn = false
        showFailure(error)
    }

    func complete(with credential: SocialCredential, displayName: String?) async {
        isSigningIn = true
        do {
            let outcome = try await SocialSignIn.run(with: credential, displayName: displayName, gateway: gateway)
            onAccountChanged()
            isSigningIn = false
            // 손님에서 가입했거나 이름이 없는 계정은 로그인 직후 닉네임을 정한다.
            if outcome.asksForNickname(currentName: gateway.currentName) {
                nicknameDraft = gateway.currentName ?? ""
                prompt = .nickname(message: "일기에서 불릴 이름을 정해주세요.\n설정에서 언제든 바꿀 수 있어요.")
            } else {
                isFinished = true
            }
        } catch {
            isSigningIn = false
            showFailure(error)
        }
    }

    func saveNickname() async {
        let name: String
        do {
            name = try Nickname.validated(nicknameDraft)
        } catch let problem as Nickname.Problem {
            // Asks again and keeps what was typed.
            prompt = .nickname(message: problem.message)
            return
        } catch {
            return
        }
        isSigningIn = true
        do {
            try await gateway.updateDisplayName(name)
            onAccountChanged()
            isSigningIn = false
            isFinished = true
        } catch {
            isSigningIn = false
            prompt = .nicknameNotSaved
        }
    }

    /// Close button, "나중에 하기", skipping the nickname, or confirming that it was not saved.
    func finish() {
        isFinished = true
    }

    // 원인을 찾을 수 있도록 오류 코드만 표시·기록한다. 토큰과 이메일은 남기지 않는다.
    private func showFailure(_ error: Error?) {
        let code = error.map { $0 as NSError }.map { "(오류: \($0.domain) \($0.code))" }
        print("Sign-in failed \(code ?? "")")
        let failure = error.map(gateway.failure(for:)) ?? .other
        prompt = .failure(message: failure.message + (code.map { "\n" + $0 } ?? ""))
    }
}
