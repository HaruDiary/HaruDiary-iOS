import SwiftUI

struct DiaryListView: View {
    @Bindable var viewModel: DiaryListViewModel
    let imageLoader: any CalendarImageLoading
    let onSelectDiary: (DiaryEntry) -> Void
    let onEditDiary: (DiaryEntry) -> Void
    let onWriteDiary: () -> Void
    let onOpenSettings: () -> Void
    /// The search button of the tab's header.
    var onOpenSearch: () -> Void = {}
    var tabRoot: TabRoot? = nil
    /// The pushed search screen: the same list under a search field, without the tab's title and write button.
    var isSearchScreen = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DiaryTheme.Colors.background.ignoresSafeArea()
            list
            if !isSearchScreen {
                DiaryWriteButton(action: onWriteDiary)
            }
        }
        .diaryStatusBarBackground()
        .onAppear { viewModel.refreshToday() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { @MainActor in viewModel.refreshToday() }
        }
        // The search screen is opened to type: the keyboard comes up once the screen has slid in
        // (focus asked for during the slide is dropped).
        .task {
            guard isSearchScreen, viewModel.query.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { isSearchFocused = true }
        }
    }

    // The title is a row too, so the whole screen scrolls together, like the calendar tab.
    private var header: some View {
        DiaryTabHeader(title: "하루일기",
                       extra: .init(systemImage: "magnifyingglass", label: "검색", action: onOpenSearch),
                       onOpenSettings: onOpenSettings)
            .listRowInsets(EdgeInsets(top: DiaryTheme.Spacing.screen, leading: DiaryTheme.Spacing.screen,
                                      bottom: DiaryTheme.Spacing.medium, trailing: DiaryTheme.Spacing.screen))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .id(TabRoot.topID)
    }

    private var searchField: some View {
        DiarySearchField(text: $viewModel.query, isFocused: $isSearchFocused)
            .listRowInsets(EdgeInsets(top: DiaryTheme.Spacing.small, leading: 0, bottom: DiaryTheme.Spacing.small, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    // A List (not a ScrollView) so rows get the system swipe actions, like Mail.
    private var list: some View {
        ScrollViewReader { proxy in
            listContent.tabRoot(tabRoot, proxy: proxy)
        }
    }

    private var listContent: some View {
        List {
            if isSearchScreen { searchField } else { header }
            if viewModel.sections.isEmpty && !viewModel.isUploadingDiary {
                placeholder
                    .frame(maxWidth: .infinity)
                    .padding(.top, DiaryTheme.Spacing.section * 3)
                    .diaryCardRow()
            }
            if viewModel.isSearching && !viewModel.sections.isEmpty {
                Text("검색 결과 \(viewModel.visibleCount)개")
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    .diaryCardRow()
            }
            if viewModel.state == .failed && !viewModel.sections.isEmpty {
                DiaryLoadFailure(onRetry: viewModel.retry).diaryCardRow()
            }
            if viewModel.isUploadingDiary {
                DiarySavingRow().diaryCardRow()
            }
            if !isSearchScreen {
                ForEach(viewModel.memories) { memory in
                    Section {
                        ForEach(memory.entries, id: \.id) { entry in
                            row(for: entry).diaryCardRow()
                        }
                    } header: {
                        Label("\(memory.yearsAgo)년 전 오늘", systemImage: "clock.arrow.circlepath")
                            .font(DiaryTheme.Fonts.section)
                            .foregroundStyle(DiaryTheme.Colors.brand)
                            .textCase(nil)
                            .padding(.horizontal, DiaryTheme.Spacing.screen)
                            .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.touchTarget, alignment: .leading)
                            .background(DiaryTheme.Colors.background)
                            .listRowInsets(EdgeInsets())
                            .accessibilityAddTraits(.isHeader)
                    }
                }
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
        .contentMargins(.bottom, DiaryTheme.Size.floatingButtonClearance, for: .scrollContent)
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
        case .failed:
            DiaryLoadFailure(onRetry: viewModel.retry)
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
