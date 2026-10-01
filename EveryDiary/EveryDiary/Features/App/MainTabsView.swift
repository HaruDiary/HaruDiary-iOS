import SwiftUI

/// The three tabs under a floating tab bar, each with its own navigation stack, and what opens over them:
/// the diary editor, sign-in and short messages.
struct MainTabsView: View {
    @Bindable var shell: AppShell
    let dependencies: AppDependencies

    @State private var modules: Once<Modules>
    /// A tab is built the first time it is opened, so its diary subscription starts only then.
    @State private var visited: Set<Int> = [0]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    struct Modules {
        let list: DiaryListModule
        let journey: JourneyModule
        let calendar: CalendarModule
    }

    init(shell: AppShell, dependencies: AppDependencies) {
        self.shell = shell
        self.dependencies = dependencies
        _modules = State(initialValue: Once {
            Modules(list: dependencies.makeDiaryListModule(), journey: dependencies.makeJourneyModule(),
                    calendar: dependencies.makeCalendarModule())
        })
    }

    var body: some View {
        let selected = shell.tabBar.selected
        ZStack {
            DiaryTheme.Colors.background.ignoresSafeArea()
            ForEach(shell.tabBar.tabs) { tab in
                if visited.contains(tab.id) {
                    NavigationStack(path: $shell.paths[tab.id]) {
                        root(of: tab.id)
                            // Room for the floating bar; pushed screens use the whole height.
                            .safeAreaPadding(.bottom, DiaryTabBar.expandedHeight + 8)
                            .navigationTitle(tab.title)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationDestination(for: AppRoute.self) { destination($0, tab: tab.id) }
                    }
                    // The tab leaving fades away while the next one fades in, settling from slightly smaller.
                    .opacity(tab.id == selected ? 1 : 0)
                    .scaleEffect(tab.id == selected || reduceMotion ? 1 : 0.97)
                    .allowsHitTesting(tab.id == selected)
                    .accessibilityHidden(tab.id != selected)
                    .zIndex(tab.id == selected ? 1 : 0)
                }
            }
        }
        .animation(.easeOut(duration: reduceMotion ? 0.18 : 0.28), value: selected)
        .tint(DiaryTheme.Colors.brand)
        .overlay(alignment: .bottom) {
            DiaryTabBar(state: shell.tabBar, onSelect: select, onExpand: shell.expandBar)
                .frame(width: DiaryTabBar.width(tabs: shell.tabBar.tabs.count, collapsed: false),
                       height: DiaryTabBar.expandedHeight)
                .allowsHitTesting(!shell.tabBar.isHidden)
                .accessibilityHidden(shell.tabBar.isHidden)
                .offset(y: 2)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            shell.isKeyboardShown = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            shell.isKeyboardShown = false
        }
        .onChange(of: shell.paths) { shell.updateBarVisibility() }
        .sheet(item: $shell.editor) { request in
            DiaryEditorScreen(
                request: request, saver: dependencies.diarySaving,
                onSaveStarted: { [list = modules.value.list.viewModel] in
                    if request.showsUploadInList { list.uploadDidStart() }
                },
                onSaveFinished: { [list = modules.value.list.viewModel] report in
                    shell.saveFinished(report)
                    if request.showsUploadInList { list.uploadDidFinish() }
                }
            )
        }
        .fullScreenCover(isPresented: $shell.isSigningIn) {
            SignInScreen(gateway: dependencies.signInGateway)
        }
        .alert("앱 암호를 정해주세요", isPresented: $shell.isAskingForPasscode) {
            Button("나중에", role: .cancel) {}
            Button("암호 정하기") { shell.isSettingPasscode = true }
        } message: {
            Text("이제 하루일기는 앱 암호로 잠가요. 암호를 정하면 Face ID도 계속 쓸 수 있어요.")
        }
        .sheet(isPresented: $shell.isSettingPasscode) {
            PasscodeSetupSheet(onClose: { shell.isSettingPasscode = false })
        }
        .diaryToast(shell.toasts)
    }

    private func select(_ tab: Int) {
        visited.insert(tab)
        shell.select(tab)
    }

    // MARK: - Tabs

    @ViewBuilder
    private func root(of tab: Int) -> some View {
        switch tab {
        case 0: DiaryListScreen(shell: shell, module: modules.value.list)
        case 1: JourneyScreen(shell: shell, viewModel: modules.value.journey.viewModel)
        default: CalendarScreen(shell: shell, module: modules.value.calendar)
        }
    }

    // MARK: - Pushed screens

    @ViewBuilder
    private func destination(_ route: AppRoute, tab: Int) -> some View {
        switch route {
        case .settings:
            SettingsScreen(shell: shell, tab: tab, makeModule: dependencies.makeSettingsModule)
        case .reminders:
            ReminderSettingsScreen(reminders: dependencies.reminders)
        case .lock:
            LockSettingsScreen()
        case .textSize:
            if let textSize = dependencies.textSize {
                TextSizeSettingsView(controller: textSize)
            }
        case .trash:
            TrashScreen(shell: shell, tab: tab, makeModule: dependencies.makeTrashModule)
        case .calendarDay:
            CalendarDayScreen(shell: shell, module: modules.value.calendar)
        case .journeyYears:
            JourneyYearsView(viewModel: modules.value.journey.viewModel, onSelectYear: { shell.push(.journeyYear($0)) })
                .navigationTitle("나의 여정")
                .navigationBarTitleDisplayMode(.inline)
        case .journeyYear(let year):
            JourneyYearScreen(viewModel: modules.value.journey.viewModel, year: year)
        }
    }
}

// MARK: - First screens of the tabs

private struct DiaryListScreen: View {
    let shell: AppShell
    let module: DiaryListModule

    var body: some View {
        let viewModel = module.viewModel
        DiaryListView(
            viewModel: viewModel, imageLoader: module.imageLoader,
            onSelectDiary: { shell.read($0) },
            onEditDiary: { shell.edit($0) },
            // Same as before: only a new diary written from the list shows its upload in the list.
            onWriteDiary: { shell.write(showsUploadInList: true) },
            onOpenSettings: { shell.push(.settings) },
            tabRoot: TabRoot(shell: shell, tab: 0)
        )
        .onAppear { viewModel.start() }
        .onChange(of: viewModel.notice) { _, notice in
            guard let notice else { return }
            viewModel.notice = nil
            switch notice {
            case .movedToTrash:
                shell.announce("삭제 완료", message: "휴지통으로 이동하였습니다.", duration: 1.0)
            case .trashFailed:
                shell.announce("삭제 실패", message: "휴지통으로 이동하지 못했습니다.\n잠시 후 다시 시도해주세요.", duration: 1.5)
            }
        }
        .onChange(of: shell.savedCount) {
            // The live subscription already reflects saved changes; only recover a failed load.
            if viewModel.state == .failed { viewModel.retry() }
        }
    }
}

private struct JourneyScreen: View {
    let shell: AppShell
    let viewModel: JourneyViewModel

    var body: some View {
        JourneyView(viewModel: viewModel,
                    onWriteDiary: { shell.write() },
                    onOpenCollection: { shell.push(.journeyYears) },
                    onOpenSettings: { shell.push(.settings) })
            .onAppear { viewModel.start() }
            .onChange(of: shell.savedCount) {
                if viewModel.state == .failed { viewModel.retry() }
            }
    }
}

private struct CalendarScreen: View {
    let shell: AppShell
    let module: CalendarModule

    var body: some View {
        let viewModel = module.viewModel
        CalendarView(
            viewModel: viewModel, imageLoader: module.imageLoader,
            onSelectDiary: { shell.read($0) },
            onOpenDayList: { shell.push(.calendarDay) },
            onWriteDiary: { shell.write() },
            onOpenSettings: { shell.push(.settings) },
            tabRoot: TabRoot(shell: shell, tab: 2)
        )
        .onAppear { viewModel.start() }
        .onChange(of: shell.savedCount) {
            // The feature's listener updates both the calendar and the day list.
            if viewModel.state == .failed { viewModel.retry() }
        }
    }
}

/// The selected day's diaries, pushed from the calendar.
private struct CalendarDayScreen: View {
    let shell: AppShell
    let module: CalendarModule

    var body: some View {
        let viewModel = module.viewModel
        CalendarDayListView(viewModel: viewModel, imageLoader: module.imageLoader,
                            onSelectDiary: { shell.read($0) }, onWriteDiary: { shell.write() })
            .navigationTitle(title(viewModel))
            .navigationBarTitleDisplayMode(.inline)
    }

    private func title(_ viewModel: CalendarViewModel) -> String {
        let formatter = DateFormatter()
        formatter.calendar = viewModel.calendar
        formatter.timeZone = viewModel.calendar.timeZone
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: viewModel.selectedDate)
    }
}
