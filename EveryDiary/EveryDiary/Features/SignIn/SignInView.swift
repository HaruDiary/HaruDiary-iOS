import SwiftUI

/// The sign-in screen from settings (mockup 20). Shows state and forwards taps; it never talks to Firebase.
struct SignInView: View {
    @Bindable var viewModel: SignInViewModel
    let onApple: () -> Void
    let onGoogle: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            DiaryTheme.Colors.onboardingBackground.ignoresSafeArea()
            VStack(spacing: DiaryTheme.Spacing.section) {
                closeButton
                Spacer(minLength: 0)
                Text("마음 놓고\n일기 쓰자")
                    .font(DiaryTheme.SignIn.title)
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Image("onboarding-mockup-keep")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: DiaryTheme.SignIn.illustrationMaxHeight)
                    .accessibilityHidden(true)
                Text("소중한 기록을 안전하게 보관하세요.")
                    .font(DiaryTheme.Fonts.body)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                Spacer(minLength: 0)
                providerButtons
            }
            .frame(maxWidth: DiaryTheme.SignIn.contentWidth)
            .padding(.horizontal, DiaryTheme.Spacing.section)
            .padding(.bottom, DiaryTheme.Spacing.small)
            // The nickname alert's keyboard must not squeeze the title behind it.
            .ignoresSafeArea(.keyboard)

            if viewModel.isSigningIn {
                ProgressView()
                    .controlSize(.large)
                    .tint(DiaryTheme.Colors.brand)
            }
        }
        .alert(viewModel.prompt?.title ?? "", isPresented: isPrompting, presenting: viewModel.prompt) { prompt in
            switch prompt {
            case .failure:
                Button("확인") {}
            case .nickname:
                TextField("닉네임 (최대 \(Nickname.maxLength)자)", text: $viewModel.nicknameDraft)
                Button("나중에", role: .cancel) { viewModel.finish() }
                // After the alert closes, so asking again after an invalid name shows a new alert.
                Button("저장") { Task { await viewModel.saveNickname() } }
            case .nicknameNotSaved:
                Button("확인") { viewModel.finish() }
            }
        } message: { prompt in
            Text(prompt.message)
        }
        .onChange(of: viewModel.isFinished) { _, finished in
            if finished { onFinish() }
        }
    }

    private var isPrompting: Binding<Bool> {
        Binding(get: { viewModel.prompt != nil }, set: { if !$0 { viewModel.prompt = nil } })
    }

    private var closeButton: some View {
        HStack {
            Button(action: viewModel.finish) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
            }
            .accessibilityLabel("닫기")
            Spacer()
        }
    }

    private var providerButtons: some View {
        VStack(spacing: DiaryTheme.Spacing.medium) {
            // Apple's button style: Apple logo and title in white on black. The system button cannot be used
            // because it follows the app's languages, and the app does not list Korean, so it would read English.
            providerButton(title: "Apple로 계속하기", foreground: .white, background: .black, action: onApple) {
                Image(systemName: "apple.logo")
                    .font(.title3)
            }
            providerButton(title: "Google로 계속하기", foreground: .black, background: .white, action: onGoogle) {
                Image("googleLogo")
                    .resizable()
                    .frame(width: DiaryTheme.SignIn.providerLogo, height: DiaryTheme.SignIn.providerLogo)
            }
            .overlay(RoundedRectangle(cornerRadius: DiaryTheme.SignIn.buttonRadius).stroke(.black.opacity(0.6)))
            Button("나중에 하기", action: viewModel.finish)
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.brand)
                .frame(minHeight: DiaryTheme.Size.touchTarget)
        }
        .disabled(viewModel.isSigningIn)
    }

    private func providerButton<Logo: View>(title: String, foreground: Color, background: Color,
                                            action: @escaping () -> Void,
                                            @ViewBuilder logo: () -> Logo) -> some View {
        Button(action: action) {
            HStack(spacing: DiaryTheme.Spacing.small) {
                logo()
                Text(title)
                    .font(.title3.weight(.medium))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: DiaryTheme.SignIn.buttonHeight)
            .background(background, in: RoundedRectangle(cornerRadius: DiaryTheme.SignIn.buttonRadius))
        }
        .buttonStyle(.plain)
    }
}
