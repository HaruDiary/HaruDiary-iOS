import SwiftUI

// Pieces shared by the diary list and the trash so both screens look and behave the same.

struct DiarySearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var placeholder = "일기 검색"
    var accessibilityIdentifier = "diaryList.search"

    var body: some View {
        HStack(spacing: DiaryTheme.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
                .focused(isFocused)
                .submitLabel(.search)
                .onSubmit { isFocused.wrappedValue = false }
                .accessibilityIdentifier(accessibilityIdentifier)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                        .frame(minWidth: DiaryTheme.Size.touchTarget, minHeight: DiaryTheme.Size.touchTarget)
                }
                .accessibilityLabel("검색어 지우기")
            }
        }
        .font(DiaryTheme.Fonts.body)
        .padding(.leading, DiaryTheme.Spacing.medium)
        .frame(minHeight: DiaryTheme.Size.touchTarget)
        .background(DiaryTheme.Colors.selection.opacity(0.35), in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .padding(.horizontal, DiaryTheme.Spacing.screen)
    }
}

struct DiaryMonthHeader: View {
    let section: DiaryListSection

    var body: some View {
        Text("\(String(section.year))년 \(section.month)월")
            .font(DiaryTheme.Fonts.section)
            .foregroundStyle(DiaryTheme.Colors.brand)
            .padding(.horizontal, DiaryTheme.Spacing.screen)
            .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.touchTarget, alignment: .leading)
            .background(DiaryTheme.Colors.background)
            .listRowInsets(EdgeInsets())
            .accessibilityAddTraits(.isHeader)
    }
}

struct DiaryLoadFailure: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DiaryTheme.Spacing.small) {
            Text("일기를 불러오지 못했어요")
                .foregroundStyle(DiaryTheme.Colors.error)
            Button("다시 시도", action: onRetry)
                .tint(DiaryTheme.Colors.brand)
                .frame(minHeight: DiaryTheme.Size.touchTarget)
        }
        .font(DiaryTheme.Fonts.body)
        .frame(maxWidth: .infinity)
    }
}

struct DiaryEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var actionSystemImage = "pencil"
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: DiaryTheme.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DiaryTheme.Colors.brand)
                .accessibilityHidden(true)
            Text(title)
                .font(DiaryTheme.Fonts.section)
                .foregroundStyle(DiaryTheme.Colors.text)
            Text(message)
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage)
                        .font(DiaryTheme.Fonts.section)
                        .foregroundStyle(DiaryTheme.Colors.surface)
                        .padding(.horizontal, DiaryTheme.Spacing.section)
                        .frame(minHeight: DiaryTheme.Size.touchTarget)
                        .background(DiaryTheme.Colors.brand, in: Capsule())
                }
                .padding(.top, DiaryTheme.Spacing.small)
            }
        }
        .multilineTextAlignment(.center)
        .padding(DiaryTheme.Spacing.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// Keeps the card look inside a plain List: no separators or row background, card spacing as insets.
    func diaryCardRow() -> some View {
        listRowInsets(EdgeInsets(top: DiaryTheme.Spacing.small / 2 + 2, leading: DiaryTheme.Spacing.screen,
                                 bottom: DiaryTheme.Spacing.small / 2 + 2, trailing: DiaryTheme.Spacing.screen))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// The plain List configuration used by card lists.
    func diaryCardList() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollDismissesKeyboard(.immediately)
    }
}
