import SwiftUI

/// Settings › 잠금 (mockup 18): the app passcode, changing it, and Face ID/Touch ID.
struct LockSettingsView: View {
    @Bindable var viewModel: LockSettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: DiaryTheme.Spacing.section) {
                header
                if viewModel.isLegacy {
                    legacyCard
                } else {
                    optionsCard
                }
                if let notice = viewModel.notice {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .font(DiaryTheme.Fonts.body)
                        .foregroundStyle(DiaryTheme.Colors.brand)
                        .transition(.opacity)
                }
                Text(footnote)
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DiaryTheme.Spacing.small)
            }
            .padding(DiaryTheme.Spacing.screen)
            .animation(.default, value: viewModel.notice)
        }
        .background(DiaryTheme.Colors.background)
        .sheet(item: $viewModel.flow, onDismiss: viewModel.flowClosed) { flow in
            PasscodeFlowView(viewModel: flow, onClose: viewModel.flowClosed)
        }
        // Shown in place for a moment; an alert could not appear while the passcode sheet is still closing.
        .task(id: viewModel.notice) {
            guard viewModel.notice != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            viewModel.noticeShown()
        }
    }

    private var header: some View {
        VStack(spacing: DiaryTheme.Spacing.small) {
            Image(systemName: viewModel.biometry?.symbolName ?? "lock.shield")
                .font(.system(size: DiaryTheme.Lock.headerIcon, weight: .light))
                .foregroundStyle(DiaryTheme.Colors.brand)
                .padding(.vertical, DiaryTheme.Spacing.medium)
                .accessibilityHidden(true)
            Text("나만 볼 수 있는 일기")
                .font(DiaryTheme.Fonts.title)
                .foregroundStyle(DiaryTheme.Colors.brand)
            Text("소중한 기록을 안전하게 지켜요.")
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
        }
        .padding(.vertical, DiaryTheme.Spacing.section)
    }

    private var optionsCard: some View {
        VStack(spacing: 0) {
            Toggle("암호 잠금", isOn: Binding(get: { viewModel.isPasscodeOn }, set: viewModel.setPasscodeOn))
                .padding(DiaryTheme.Spacing.screen)
            if viewModel.isPasscodeOn {
                Divider().padding(.leading, DiaryTheme.Spacing.screen)
                Button(action: viewModel.changePasscode) {
                    HStack {
                        Text("암호 변경")
                            .foregroundStyle(DiaryTheme.Colors.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    }
                    .padding(DiaryTheme.Spacing.screen)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let name = viewModel.biometryName {
                    Divider().padding(.leading, DiaryTheme.Spacing.screen)
                    Toggle("\(name)로 잠금 해제", isOn: Binding(
                        get: { viewModel.isBiometricsOn },
                        set: { on in Task { await viewModel.setBiometricsOn(on) } }
                    ))
                    .padding(DiaryTheme.Spacing.screen)
                }
            }
        }
        .font(DiaryTheme.Fonts.body)
        .foregroundStyle(DiaryTheme.Colors.text)
        .tint(DiaryTheme.Colors.brand)
        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
    }

    private var legacyCard: some View {
        VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
            Text("이전 버전의 Face ID 잠금이 켜져 있어요. 앱 암호를 정하면 새 잠금으로 바뀌고 Face ID도 계속 쓸 수 있어요.")
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.text)
            Button("앱 암호 정하기") { viewModel.setPasscodeOn(true) }
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.brand)
            Button("잠금 끄기") { Task { await viewModel.turnOffLegacyLock() } }
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.error)
        }
        .padding(DiaryTheme.Spacing.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
    }

    private var footnote: String {
        guard viewModel.isPasscodeOn else {
            return "암호를 켜면 앱을 열 때마다 잠금을 확인해요."
        }
        let way = viewModel.isBiometricsOn ? "암호나 \(viewModel.biometryName ?? "생체 인식")" : "암호"
        return "앱을 열 때 \(way)로 확인해요. 암호를 잊으면 iPhone 암호로 본인을 확인한 뒤 잠금을 끌 수 있어요."
    }
}
