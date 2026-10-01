import Observation
import SwiftUI

/// Values the rows show on the right; refreshed each time settings appear, since they change on the pushed screens.
@MainActor
@Observable
final class SettingsRowValues {
    var reminder = ""
    var lock = ""
    var textSize = ""
    var version = ""
}

/// Pages the app links to.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://woozy-stick-dd0.notion.site/dc4303c83cd3453e98ada95ff0275209")!
}

/// Screens and system sheets that settings open (`SettingsScreen`).
struct SettingsActions {
    var openReminders: () -> Void
    var openLock: () -> Void
    var openTextSize: () -> Void
    var openTrash: () -> Void
    /// Opens a web page inside the app.
    var openWebPage: (URL) -> Void
    var signIn: () -> Void
    /// Apple members confirm with Sign in with Apple before their account is deleted.
    var confirmWithAppleThenDelete: () -> Void
    /// Signed out or deleted: the account session refreshes its user.
    var accountChanged: () -> Void
}

/// Settings (mockup 16): profile, reminders, lock, trash, and account actions.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let values: SettingsRowValues
    let actions: SettingsActions
    /// Shows the uploaded profile photo from the device; nil in previews.
    var profilePhotos: ProfilePhotoLoader? = nil

    @State private var isEditingProfile = false
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDeletion = false
    @State private var alert: SettingsAlert?
    @State private var savedToast = false

    var body: some View {
        List {
            Section {
                profileRow
            }
            Section {
                row("알림", systemImage: "bell", value: values.reminder, action: actions.openReminders)
                row("잠금", systemImage: "lock", value: values.lock, action: actions.openLock)
                row("글자 크기", systemImage: "textformat.size", value: values.textSize, action: actions.openTextSize)
                row("최근 삭제한 항목", systemImage: "trash", value: nil, action: actions.openTrash)
            }
            Section {
                row("개인정보 처리방침", systemImage: "hand.raised", value: nil) {
                    actions.openWebPage(AppLinks.privacyPolicy)
                }
            }
            if viewModel.profile.isLoggedIn {
                Section {
                    destructiveRow("로그아웃", systemImage: "rectangle.portrait.and.arrow.right") {
                        isConfirmingSignOut = true
                    }
                    destructiveRow("회원 탈퇴", systemImage: "person.crop.circle.badge.xmark") {
                        isConfirmingDeletion = true
                    }
                }
            }
            Section {
            } footer: {
                Text(values.version)
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DiaryTheme.Colors.background)
        .tint(DiaryTheme.Colors.brand)
        .disabled(viewModel.isDeletingAccount)
        .overlay {
            // Erasing many diaries and photos takes a while; the screen waits instead of accepting other actions.
            if viewModel.isDeletingAccount {
                ProgressView("탈퇴하는 중…")
                    .padding(DiaryTheme.Spacing.section)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
            }
        }
        .overlay(alignment: .top) {
            if savedToast {
                Label("프로필을 저장했어요", systemImage: "checkmark.circle.fill")
                    .font(DiaryTheme.Fonts.body)
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .padding(.horizontal, DiaryTheme.Spacing.screen)
                    .padding(.vertical, DiaryTheme.Spacing.small)
                    .background(.regularMaterial, in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: savedToast)
        .alert("로그아웃 하시겠습니까?", isPresented: $isConfirmingSignOut) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) { viewModel.signOut() }
        }
        .confirmationDialog("회원 탈퇴하시겠습니까?", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
            Button("회원 탈퇴", role: .destructive) {
                if viewModel.needsAppleConfirmationToDelete {
                    actions.confirmWithAppleThenDelete()
                } else {
                    Task { await viewModel.deleteAccount() }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("작성한 일기와 사진이 모두 삭제되며 복구할 수 없습니다.")
        }
        .alert(alert?.title ?? "", isPresented: isShowingAlert, presenting: alert) { shown in
            Button("확인") { shown.afterConfirm?() }
        } message: { shown in
            Text(shown.message)
        }
        .sheet(isPresented: $isEditingProfile) {
            ProfileEditView(
                nickname: viewModel.nickname, picture: viewModel.profile.picture, profilePhotos: profilePhotos,
                onSave: { nickname, picture in await viewModel.updateProfile(nickname: nickname, picture: picture) },
                onClose: { isEditingProfile = false }
            )
        }
        .onChange(of: viewModel.notice) { _, notice in
            guard let notice else { return }
            viewModel.notice = nil
            show(notice)
        }
    }

    private var isShowingAlert: Binding<Bool> {
        Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })
    }

    // MARK: - Rows

    private var profileRow: some View {
        let profile = viewModel.profile
        return Button {
            // 로그인한 경우 프로필을 누르면 프로필 사진·닉네임을 바꾼다. 로그인 전에는 로그인한다.
            if viewModel.canManageAccount {
                isEditingProfile = true
            } else {
                actions.signIn()
            }
        } label: {
            HStack(spacing: DiaryTheme.Spacing.medium) {
                ProfilePictureView(picture: profile.picture, pickedPhoto: nil, size: 56, photos: profilePhotos)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(DiaryTheme.Fonts.section)
                        .foregroundStyle(DiaryTheme.Colors.brand)
                    Text(profile.detail)
                        .font(DiaryTheme.Fonts.caption)
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if profile.isLoggedIn {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                } else {
                    Text("로그인")
                        .font(DiaryTheme.Fonts.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DiaryTheme.Spacing.medium)
                        .padding(.vertical, 6)
                        .background(DiaryTheme.Colors.brand, in: Capsule())
                }
            }
            .padding(.vertical, DiaryTheme.Spacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(profile.isLoggedIn ? "프로필 사진과 닉네임을 바꿉니다" : "로그인합니다")
    }

    private func row(_ title: String, systemImage: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DiaryTheme.Spacing.medium) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .frame(width: DiaryTheme.Size.icon)
                Text(title)
                    .foregroundStyle(DiaryTheme.Colors.text)
                Spacer(minLength: DiaryTheme.Spacing.small)
                if let value, !value.isEmpty {
                    Text(value)
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
            }
            .font(DiaryTheme.Fonts.body)
            .frame(minHeight: DiaryTheme.Size.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func destructiveRow(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DiaryTheme.Spacing.medium) {
                Image(systemName: systemImage)
                    .frame(width: DiaryTheme.Size.icon)
                Text(title)
                Spacer()
            }
            .font(DiaryTheme.Fonts.body)
            .foregroundStyle(DiaryTheme.Colors.error)
            .frame(minHeight: DiaryTheme.Size.touchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Results

    private func show(_ notice: SettingsViewModel.Notice) {
        switch notice {
        case .signedOut:
            actions.accountChanged()
            alert = SettingsAlert(title: "로그아웃", message: "로그아웃이 완료되었습니다.", afterConfirm: actions.signIn)
        case .accountDeleted:
            actions.accountChanged()
            alert = SettingsAlert(title: "회원 탈퇴", message: "회원 탈퇴가 완료되었습니다.", afterConfirm: actions.signIn)
        case .profileSaved:
            isEditingProfile = false
            savedToast = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                savedToast = false
            }
        case .nicknameInvalid:
            // The editor stays open and already shows the problem under its field.
            break
        default:
            alert = SettingsAlert(notice)
        }
    }
}

private struct SettingsAlert {
    let title: String
    let message: String
    var afterConfirm: (() -> Void)?

    init(title: String, message: String, afterConfirm: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.afterConfirm = afterConfirm
    }

    // The same wording as the previous settings screen.
    init(_ notice: SettingsViewModel.Notice) {
        switch notice {
        case .signOutFailed:
            self.init(title: "로그아웃 실패", message: "로그아웃하지 못했습니다.\n잠시 후 다시 시도해주세요.")
        case .deletionNeedsRecentLogin:
            self.init(title: "다시 로그인이 필요해요", message: "보안을 위해 로그아웃 후 다시 로그인한 뒤\n바로 탈퇴해주세요.")
        case .dataErasedNeedsRecentLogin:
            self.init(title: "탈퇴를 마치려면 다시 로그인해주세요",
                      message: "일기와 사진은 모두 삭제되었어요.\n로그아웃 후 다시 로그인한 뒤 탈퇴를 한 번 더 눌러주세요.")
        case .appleConfirmationFailed:
            self.init(title: "회원 탈퇴 실패", message: "로그인한 Apple 계정으로 확인해주세요.\n다른 Apple 계정으로는 탈퇴할 수 없어요.")
        case .appleRevocationFailed:
            self.init(title: "회원 탈퇴 실패",
                      message: "Apple 로그인 연결을 해제하지 못해 탈퇴를 멈췄어요.\n일기와 사진은 그대로예요. 잠시 후 다시 시도해주세요.")
        case .dataErasureFailed:
            self.init(title: "회원 탈퇴 실패", message: "일기와 사진을 모두 지우지 못해 탈퇴를 멈췄어요.\n잠시 후 다시 시도해주세요.")
        default:
            self.init(title: "회원 탈퇴 실패", message: "회원 탈퇴를 완료하지 못했습니다.\n잠시 후 다시 시도해주세요.")
        }
    }
}
