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
        HStack(spacing: DiaryTheme.Spacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .accessibilityHidden(true)
            TextField("일기 검색", text: $viewModel.query)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit { isSearchFocused = false }
                .accessibilityIdentifier("diaryList.search")
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
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

    @ViewBuilder
    private var content: some View {
        if viewModel.sections.isEmpty && !viewModel.isUploadingDiary {
            placeholder
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium, pinnedViews: [.sectionHeaders]) {
                if viewModel.isSearching {
                    Text("검색 결과 \(viewModel.visibleCount)개")
                        .font(DiaryTheme.Fonts.caption)
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                }
                if viewModel.state == .failed {
                    DiaryListLoadFailure(onRetry: viewModel.retry)
                }
                if viewModel.isUploadingDiary {
                    DiaryListUploadingRow()
                }
                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.entries, id: \.id) { entry in
                            row(for: entry)
                        }
                    } header: {
                        monthHeader(section)
                    }
                }
            }
            .padding(.horizontal, DiaryTheme.Spacing.screen)
            .padding(.bottom, DiaryTheme.Size.floatingButton + DiaryTheme.Spacing.section)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { viewModel.retry() }
    }

    private func row(for entry: DiaryEntry) -> some View {
        Button { leaveSearch { onSelectDiary(entry) } } label: {
            DiaryListRow(entry: entry, calendar: viewModel.calendar, imageLoader: imageLoader)
        }
        .buttonStyle(.plain)
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

    private func monthHeader(_ section: DiaryListSection) -> some View {
        Text("\(String(section.year))년 \(section.month)월")
            .font(DiaryTheme.Fonts.section)
            .foregroundStyle(DiaryTheme.Colors.brand)
            .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.touchTarget, alignment: .leading)
            .background(DiaryTheme.Colors.background)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var placeholder: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("일기를 불러오는 중이에요")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            DiaryListLoadFailure(onRetry: viewModel.retry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            if viewModel.isSearching {
                DiaryListEmptyState(
                    systemImage: "magnifyingglass",
                    title: "검색 결과가 없어요",
                    message: "제목이나 내용의 다른 단어로 찾아보세요."
                )
            } else {
                DiaryListEmptyState(
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

private struct DiaryListLoadFailure: View {
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

private struct DiaryListEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
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
                    Label(actionTitle, systemImage: "pencil")
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
