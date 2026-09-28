import SwiftUI

struct DiaryListView: View {
    @Bindable var viewModel: DiaryListViewModel
    let imageLoader: any CalendarImageLoading
    let onSelectDiary: (DiaryEntry) -> Void
    let onEditDiary: (DiaryEntry) -> Void
    let onWriteDiary: () -> Void
    let onOpenSettings: () -> Void
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DiaryTheme.Colors.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
                header
                searchField
                content
            }
            DiaryWriteButton { leaveSearch(then: onWriteDiary) }
                .padding(DiaryTheme.Spacing.screen)
        }
    }

    private var header: some View {
        HStack {
            Text("하루일기")
                .font(DiaryTheme.Fonts.title)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { leaveSearch(then: onOpenSettings) } label: {
                Image(systemName: "gearshape").font(.system(size: DiaryTheme.Size.icon))
                    .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
            }
            .accessibilityLabel("설정")
        }
        .foregroundStyle(DiaryTheme.Colors.brand)
        .padding(.horizontal, DiaryTheme.Spacing.screen)
    }

    private var searchField: some View {
        DiarySearchField(text: $viewModel.query, isFocused: $isSearchFocused)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.sections.isEmpty && !viewModel.isUploadingDiary {
            placeholder
        } else {
            list
        }
    }

    // A List (not a ScrollView) so rows get the system swipe actions, like Mail.
    private var list: some View {
        List {
            if viewModel.isSearching {
                Text("검색 결과 \(viewModel.visibleCount)개")
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    .diaryCardRow()
            }
            if viewModel.state == .failed {
                DiaryLoadFailure(onRetry: viewModel.retry).diaryCardRow()
            }
            if viewModel.isUploadingDiary {
                DiaryListUploadingRow().diaryCardRow()
            }
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.entries, id: \.id) { entry in
                        row(for: entry).diaryCardRow()
                    }
                } header: {
                    DiaryMonthHeader(section: section)
                }
            }
        }
        .diaryCardList()
        .contentMargins(.bottom, DiaryTheme.Size.floatingButton + DiaryTheme.Spacing.section, for: .scrollContent)
        .refreshable { viewModel.retry() }
    }

    private func row(for entry: DiaryEntry) -> some View {
        Button { leaveSearch { onSelectDiary(entry) } } label: {
            DiaryListRow(entry: entry, calendar: viewModel.calendar, imageLoader: imageLoader)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await viewModel.moveToTrash(entry) }
            } label: {
                Label("휴지통", systemImage: "trash")
            }
            Button { leaveSearch { onEditDiary(entry) } } label: {
                Label("수정", systemImage: "pencil")
            }
            .tint(DiaryTheme.Colors.brand)
        }
        .contextMenu {
            Button { leaveSearch { onEditDiary(entry) } } label: { Label("수정", systemImage: "pencil") }
            Button(role: .destructive) {
                Task { await viewModel.moveToTrash(entry) }
            } label: {
                Label("휴지통", systemImage: "trash")
            }
        }
    }

    // Presented screens would otherwise hand focus back to the search field when they close.
    private func leaveSearch(then action: () -> Void) {
        isSearchFocused = false
        action()
    }

    @ViewBuilder
    private var placeholder: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("일기를 불러오는 중이에요")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            DiaryLoadFailure(onRetry: viewModel.retry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if viewModel.isSearching {
                DiaryEmptyState(
                    systemImage: "magnifyingglass",
                    title: "검색 결과가 없어요",
                    message: "제목이나 내용의 다른 단어로 찾아보세요."
                )
            } else {
                DiaryEmptyState(
                    systemImage: "book",
                    title: "아직 작성한 일기가 없어요",
                    message: "오늘의 이야기를 남겨보세요.",
                    actionTitle: "첫 일기 쓰기",
                    action: { leaveSearch(then: onWriteDiary) }
                )
            }
        }
    }
}

private struct DiaryListUploadingRow: View {
    var body: some View {
        HStack(spacing: DiaryTheme.Spacing.medium) {
            ProgressView()
            Text("일기를 저장하고 있어요")
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.thumbnail)
        .background(DiaryTheme.Colors.selection.opacity(0.5), in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        .accessibilityElement(children: .combine)
    }
}
