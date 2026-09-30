import SwiftUI

/// Covers the app until it is unlocked. Shows no diary content.
struct LockScreenView: View {
    @Bindable var viewModel: LockScreenViewModel

    var body: some View {
        ZStack {
            DiaryTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: DiaryTheme.Spacing.section) {
                Spacer(minLength: DiaryTheme.Spacing.section)
                Image(systemName: "lock.fill")
                    .font(.system(size: DiaryTheme.Lock.headerIcon / 2))
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .accessibilityHidden(true)
                Text("하루일기")
                    .font(DiaryTheme.Fonts.title)
                    .foregroundStyle(DiaryTheme.Colors.brand)
                if viewModel.isLegacy {
                    legacyUnlock
                } else {
                    passcodeUnlock
                }
            }
            .padding(.horizontal, DiaryTheme.Spacing.section)
            .padding(.bottom, DiaryTheme.Spacing.small)
        }
    }

    private var passcodeUnlock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let waitUntil = viewModel.waitUntil
            VStack(spacing: DiaryTheme.Spacing.section) {
                Text("암호를 입력하세요")
                    .font(DiaryTheme.Fonts.section)
                    .foregroundStyle(DiaryTheme.Colors.text)
                PasscodeDots(filled: viewModel.digits.count, mistakes: viewModel.mistakes)
                Text(waitUntil.map { LockMessages.remaining(until: $0, now: context.date) } ?? viewModel.message ?? " ")
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.error)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 32)
                Spacer(minLength: 0)
                PasscodeKeypad(isDisabled: waitUntil != nil || viewModel.isAuthenticating,
                               onDigit: viewModel.type, onDelete: viewModel.deleteLast) {
                    if let biometry = viewModel.biometry {
                        Button {
                            Task { await viewModel.useBiometrics() }
                        } label: {
                            Image(systemName: biometry.symbolName)
                                .font(.title)
                                .foregroundStyle(DiaryTheme.Colors.brand)
                                .frame(width: DiaryTheme.Lock.keySize, height: DiaryTheme.Lock.keySize)
                        }
                        .accessibilityLabel("\(biometry.name ?? "생체 인식")로 잠금 해제")
                    }
                }
                Button("암호를 잊었어요") {
                    Task { await viewModel.forgotPasscode() }
                }
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .frame(minHeight: DiaryTheme.Size.touchTarget)
                .disabled(viewModel.isAuthenticating)
            }
        }
    }

    /// Set up by an earlier version: unlock the same way as before, then the app asks for a passcode.
    private var legacyUnlock: some View {
        VStack(spacing: DiaryTheme.Spacing.section) {
            Text("Face ID 또는 iPhone 암호로\n잠금을 해제하세요")
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button {
                Task { await viewModel.unlockAsDeviceOwner() }
            } label: {
                Text("잠금 해제")
                    .font(DiaryTheme.Fonts.section)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: DiaryTheme.SignIn.buttonHeight)
                    .background(DiaryTheme.Colors.brand, in: RoundedRectangle(cornerRadius: DiaryTheme.SignIn.buttonRadius))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isAuthenticating)
        }
    }
}

/// Setting, changing or turning off the passcode, shown as a sheet from lock settings.
struct PasscodeFlowView: View {
    @Bindable var viewModel: PasscodeFlowViewModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let waitUntil = viewModel.waitUntil
                VStack(spacing: DiaryTheme.Spacing.section) {
                    Spacer(minLength: DiaryTheme.Spacing.section)
                    Text(viewModel.title)
                        .font(DiaryTheme.Fonts.section)
                        .foregroundStyle(DiaryTheme.Colors.text)
                    PasscodeDots(filled: viewModel.digits.count, mistakes: viewModel.mistakes)
                    Text(waitUntil.map { LockMessages.remaining(until: $0, now: context.date) } ?? viewModel.message ?? " ")
                        .font(DiaryTheme.Fonts.caption)
                        .foregroundStyle(DiaryTheme.Colors.error)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 32)
                    Spacer(minLength: 0)
                    PasscodeKeypad(isDisabled: waitUntil != nil, onDigit: viewModel.type, onDelete: viewModel.deleteLast)
                }
                .padding([.horizontal, .bottom], DiaryTheme.Spacing.section)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DiaryTheme.Colors.background)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onClose)
                        .tint(DiaryTheme.Colors.brand)
                }
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: viewModel.isDone) { _, done in
            if done { onClose() }
        }
    }

    private var navigationTitle: String {
        switch viewModel.purpose {
        case .create: return "암호 설정"
        case .change: return "암호 변경"
        case .turnOff: return "암호 끄기"
        }
    }
}
