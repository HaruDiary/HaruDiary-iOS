import SwiftUI

struct TrashView: View {
    @Bindable var viewModel: TrashViewModel
    let imageLoader: any CalendarImageLoading
    let onSelectDiary: (DiaryEntry) -> Void
    @FocusState private var isSearchFocused: Bool
    @State private var pendingDeletion: DiaryEntry?
    @State private var isConfirmingEmptyTrash = false

    var body: some View {
        ZStack {
            DiaryTheme.Colors.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
                header
                DiarySearchField(text: $viewModel.query, isFocused: $isSearchFocused,
                                 placeholder: "휴지통 검색", accessibilityIdentifier: "trash.search")
                content
            }
            .padding(.top, DiaryTheme.Spacing.small)
        }
        .confirmationDialog("이 일기를 영구 삭제할까요?", isPresented: isConfirmingDeletion, titleVisibility: .visible,
                            presenting: pendingDeletion) { entry in
            Button("영구 삭제", role: .destructive) {
                Task { await viewModel.deletePermanently(entry) }
            }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("영구 삭제한 일기와 사진은 복구할 수 없어요.")
        }
        .confirmationDialog("휴지통을 비울까요?", isPresented: $isConfirmingEmptyTrash, titleVisibility: .visible) {
            Button("모두 영구 삭제", role: .destructive) {
                Task { await viewModel.emptyTrash() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("휴지통의 일기 \(viewModel.trashedCount)개가 영구 삭제되며 복구할 수 없어요.")
        }
    }

    private var isConfirmingDeletion: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var isBulkMenuDisabled: Bool {
        viewModel.trashedCount == 0 || viewModel.isPerformingBulkAction
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
            HStack {
                Text("최근 삭제한 항목")
                    .font(DiaryTheme.Fonts.section)
                    .foregroundStyle(DiaryTheme.Colors.text)
                    .accessibilityAddTraits(.isHeader)
                if viewModel.isPerformingBulkAction {
                    ProgressView().padding(.leading, DiaryTheme.Spacing.small)
                }
                Spacer()
                Menu {
                    Button {
                        Task { await viewModel.restoreAll() }
                    } label: {
                        Label("모두 복원", systemImage: "arrow.uturn.backward")
                    }
                    Button(role: .destructive) {
                        isConfirmingEmptyTrash = true
                    } label: {
                        Label("비우기", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: DiaryTheme.Size.icon))
                        .foregroundStyle(isBulkMenuDisabled ? DiaryTheme.Colors.secondaryText : DiaryTheme.Colors.brand)
                        .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                }
                .disabled(isBulkMenuDisabled)
                .accessibilityLabel("휴지통 전체 작업")
            }
            Label("휴지통의 일기는 \(DiaryTrashPolicy.retentionDays)일 후 완전히 삭제돼요.", systemImage: "clock")
                .font(DiaryTheme.Fonts.caption)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
        }
        .padding(.horizontal, DiaryTheme.Spacing.screen)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.sections.isEmpty {
            placeholder
        } else {
            list
        }
    }

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
        .contentMargins(.bottom, DiaryTheme.Spacing.section, for: .scrollContent)
        .refreshable { viewModel.retry() }
    }

    private func row(for entry: DiaryEntry) -> some View {
        Button {
            isSearchFocused = false
            onSelectDiary(entry)
        } label: {
            DiaryListRow(entry: entry, calendar: viewModel.calendar, imageLoader: imageLoader, badge: badge(for: entry))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeletion = entry
            } label: {
                Label("영구 삭제", systemImage: "trash.slash")
            }
            Button {
                Task { await viewModel.restore(entry) }
            } label: {
                Label("복원", systemImage: "arrow.uturn.backward")
            }
            .tint(DiaryTheme.Colors.brand)
        }
        .contextMenu {
            Button {
                Task { await viewModel.restore(entry) }
            } label: {
                Label("복원", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive) {
                pendingDeletion = entry
            } label: {
                Label("영구 삭제", systemImage: "trash.slash")
            }
        }
    }

    private func badge(for entry: DiaryEntry) -> DiaryRowBadge? {
        guard let days = viewModel.daysRemaining(for: entry) else { return nil }
        let text = days == 0 ? "곧 삭제" : "\(days)일 남음"
        return DiaryRowBadge(text: text, isUrgent: days <= 3)
    }

    @ViewBuilder
    private var placeholder: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("휴지통을 불러오는 중이에요")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            DiaryLoadFailure(onRetry: viewModel.retry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if viewModel.isSearching {
                DiaryEmptyState(systemImage: "magnifyingglass", title: "검색 결과가 없어요",
                                message: "제목이나 내용의 다른 단어로 찾아보세요.")
            } else {
                DiaryEmptyState(systemImage: "trash", title: "휴지통이 비어 있어요",
                                message: "삭제한 일기는 \(DiaryTrashPolicy.retentionDays)일 동안 여기에 보관돼요.")
            }
        }
    }
}
