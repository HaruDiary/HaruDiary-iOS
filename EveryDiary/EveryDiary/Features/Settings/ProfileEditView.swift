import SwiftUI

/// Picks a profile picture and nickname together. Saving is done by the caller.
struct ProfileEditView: View {
    @State private var nickname: String
    @State private var avatar: ProfileAvatar
    @FocusState private var isNicknameFocused: Bool
    let onSave: (String, ProfileAvatar) -> Void
    let onCancel: () -> Void

    init(nickname: String?, avatar: ProfileAvatar, onSave: @escaping (String, ProfileAvatar) -> Void, onCancel: @escaping () -> Void) {
        _nickname = State(initialValue: nickname ?? "")
        _avatar = State(initialValue: avatar)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var problem: Nickname.Problem? {
        do {
            _ = try Nickname.validated(nickname)
            return nil
        } catch {
            return error as? Nickname.Problem
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DiaryTheme.Spacing.section) {
                    ProfileAvatarView(avatar: avatar, size: 104)
                        .padding(.top, DiaryTheme.Spacing.small)
                        .animation(.spring(duration: 0.25), value: avatar)
                    avatarGrid
                    nicknameField
                }
                .padding(DiaryTheme.Spacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DiaryTheme.Colors.background)
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { onSave(nickname, avatar) }
                        .fontWeight(.semibold)
                        .disabled(problem != nil)
                }
            }
            .tint(DiaryTheme.Colors.brand)
        }
    }

    private var avatarGrid: some View {
        VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
            Text("프로필 색상")
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.text)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DiaryTheme.Spacing.medium), count: 4),
                      spacing: DiaryTheme.Spacing.medium) {
                ForEach(ProfileAvatar.allCases, id: \.self) { option in
                    Button {
                        avatar = option
                    } label: {
                        ProfileAvatarView(avatar: option, size: 60)
                            .padding(4)
                            .overlay {
                                Circle().strokeBorder(DiaryTheme.Colors.brand, lineWidth: option == avatar ? 3 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.label(for: option))
                    .accessibilityAddTraits(option == avatar ? .isSelected : [])
                }
            }
        }
        .padding(DiaryTheme.Spacing.screen)
        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
    }

    private var nicknameField: some View {
        VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
            Text("닉네임")
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.text)
            TextField("닉네임을 입력해주세요", text: $nickname)
                .focused($isNicknameFocused)
                .submitLabel(.done)
                .padding(.horizontal, DiaryTheme.Spacing.medium)
                .frame(minHeight: DiaryTheme.Size.touchTarget)
                .background(DiaryTheme.Colors.selection.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Text(problem.map(NicknameAlert.problemMessage) ?? "일기에서 불릴 이름이에요.")
                    .foregroundStyle(problem == nil ? DiaryTheme.Colors.secondaryText : DiaryTheme.Colors.error)
                Spacer()
                Text("\(nickname.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(Nickname.maxLength)")
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    .monospacedDigit()
            }
            .font(DiaryTheme.Fonts.caption)
        }
        .padding(DiaryTheme.Spacing.screen)
        .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
    }

    private static func label(for avatar: ProfileAvatar) -> String {
        switch avatar {
        case .purple: "보라"
        case .violet: "바이올렛"
        case .lavender: "라벤더"
        case .green: "초록"
        case .blue: "파랑"
        case .orange: "주황"
        case .brown: "갈색"
        case .pink: "분홍"
        }
    }
}
