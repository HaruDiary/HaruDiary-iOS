import PhotosUI
import SwiftUI

/// Picks a profile picture (built-in avatar or a library photo) and nickname together.
/// Saving is started by the caller; the editor stays open when it fails so the member can retry.
struct ProfileEditView: View {
    @State private var nickname: String
    @State private var selection: ProfilePictureSelection
    /// Shown for a picked photo until it is uploaded.
    @State private var pickedPhoto: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isSaving = false
    @State private var message: String?
    let onSave: (String, ProfilePictureSelection) async -> Bool
    let onClose: () -> Void

    init(nickname: String?, picture: ProfilePicture?, onSave: @escaping (String, ProfilePictureSelection) async -> Bool,
         onClose: @escaping () -> Void) {
        _nickname = State(initialValue: nickname ?? "")
        switch picture {
        case .photo(let url): _selection = State(initialValue: .currentPhoto(url))
        case .avatar(let avatar): _selection = State(initialValue: .avatar(avatar))
        case nil: _selection = State(initialValue: .avatar(.google))
        }
        self.onSave = onSave
        self.onClose = onClose
    }

    private var problem: Nickname.Problem? {
        do {
            _ = try Nickname.validated(nickname)
            return nil
        } catch {
            return error as? Nickname.Problem
        }
    }

    private var previewPicture: ProfilePicture? {
        switch selection {
        case .avatar(let avatar): .avatar(avatar)
        case .currentPhoto(let url): .photo(url)
        case .newPhoto: nil
        }
    }

    private var selectedAvatar: ProfileAvatar? {
        if case .avatar(let avatar) = selection { return avatar }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DiaryTheme.Spacing.section) {
                    VStack(spacing: DiaryTheme.Spacing.medium) {
                        ProfilePictureView(picture: previewPicture, pickedPhoto: pickedPhoto, size: 104)
                            .overlay { if isLoadingPhoto { ProgressView() } }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("앨범에서 사진 선택", systemImage: "photo.on.rectangle")
                                .font(DiaryTheme.Fonts.body.weight(.semibold))
                                .padding(.horizontal, DiaryTheme.Spacing.screen)
                                .frame(minHeight: DiaryTheme.Size.touchTarget)
                                .background(DiaryTheme.Colors.selection.opacity(0.35), in: Capsule())
                        }
                        .disabled(isSaving || isLoadingPhoto)
                    }
                    .padding(.top, DiaryTheme.Spacing.small)
                    avatarGrid
                    nicknameField
                    if let message {
                        Text(message)
                            .font(DiaryTheme.Fonts.caption)
                            .foregroundStyle(DiaryTheme.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(DiaryTheme.Spacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DiaryTheme.Colors.background)
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onClose).disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("저장", action: save)
                            .fontWeight(.semibold)
                            .disabled(problem != nil || isLoadingPhoto)
                    }
                }
            }
            .tint(DiaryTheme.Colors.brand)
            .interactiveDismissDisabled(isSaving)
            .onChange(of: photoItem) { _, item in
                if let item { loadPhoto(item) }
            }
        }
    }

    private var avatarGrid: some View {
        VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
            Text("기본 프로필")
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.text)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DiaryTheme.Spacing.medium), count: 4),
                      spacing: DiaryTheme.Spacing.medium) {
                ForEach(ProfileAvatar.allCases, id: \.self) { option in
                    Button {
                        selection = .avatar(option)
                        pickedPhoto = nil
                        message = nil
                    } label: {
                        ProfileAvatarView(avatar: option, size: 60)
                            .padding(4)
                            .overlay {
                                Circle().strokeBorder(DiaryTheme.Colors.brand, lineWidth: option == selectedAvatar ? 3 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .accessibilityLabel(Self.label(for: option))
                    .accessibilityAddTraits(option == selectedAvatar ? .isSelected : [])
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
                .submitLabel(.done)
                .disabled(isSaving)
                .padding(.horizontal, DiaryTheme.Spacing.medium)
                .frame(minHeight: DiaryTheme.Size.touchTarget)
                .background(DiaryTheme.Colors.selection.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Text(problem.map(\.message) ?? "일기에서 불릴 이름이에요.")
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

    // Reading can fail (e.g. an iCloud photo that cannot be downloaded); the previous choice then stays.
    private func loadPhoto(_ item: PhotosPickerItem) {
        isLoadingPhoto = true
        message = nil
        Task {
            defer {
                isLoadingPhoto = false
                photoItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let prepared = ProfilePhotoPreparation.prepare(data) else {
                message = "사진을 불러오지 못했어요. 다른 사진을 골라주세요."
                return
            }
            pickedPhoto = prepared.image
            selection = .newPhoto(prepared.jpeg)
        }
    }

    private func save() {
        isSaving = true
        message = nil
        Task {
            if await onSave(nickname, selection) {
                onClose()
            } else {
                isSaving = false
                message = "프로필을 저장하지 못했어요. 이전 프로필은 그대로예요. 다시 시도해주세요."
            }
        }
    }

    private static func label(for avatar: ProfileAvatar) -> String {
        switch avatar {
        case .google: "초록 (Google 기본)"
        case .apple: "파랑 (Apple 기본)"
        case .lavender: "라벤더"
        case .mint: "민트"
        case .peach: "살구"
        case .pink: "분홍"
        case .sky: "하늘"
        case .violet: "보라"
        }
    }
}
