import Observation
import SwiftUI

/// Screens pushed inside a tab.
enum AppRoute: Hashable {
    case settings
    case reminders
    case lock
    case textSize
    case trash
    case calendarDay
    case journeyYears
    case journeyYear(Int)
}

/// Opening the diary editor: writing a new diary, or reading or editing a stored one.
struct DiaryEditorRequest: Identifiable {
    enum Purpose {
        case compose
        case read(DiaryEntry)
        case edit(DiaryEntry)
    }

    let id = UUID()
    let purpose: Purpose
    /// The list shows a "saving" row while a new diary written from it is uploaded.
    var showsUploadInList = false
}

/// What the tabs share: the floating tab bar, the editor sheet, short messages and the paths of pushed screens.
@MainActor
@Observable
final class AppShell {
    let tabBar = DiaryTabBarState(tabs: [
        DiaryTab(id: 0, title: "나의 일기", image: "diary"),
        DiaryTab(id: 1, title: "여정", image: "building"),
        DiaryTab(id: 2, title: "캘린더", image: "calendar"),
    ])
    let toasts = DiaryToastCenter()

    /// One path per tab; a tab keeps its pushed screens while another is shown.
    var paths: [[AppRoute]] = [[], [], []]
    var editor: DiaryEditorRequest? {
        didSet { showWhatWaitedForTheSheet() }
    }
    var isSigningIn = false {
        didSet { showWhatWaitedForTheSheet() }
    }
    /// After the earlier biometrics-only lock: invites the user to set the app passcode that replaces it.
    var isAskingForPasscode = false
    var isSettingPasscode = false {
        didSet { showWhatWaitedForTheSheet() }
    }

    /// Goes up when a diary was saved; screens whose loading failed load again.
    private(set) var savedCount = 0
    /// Goes up when the open tab is tapped again; its first screen scrolls to the top.
    private(set) var scrollToTopCount = 0

    @ObservationIgnored private var collapse = TabBarCollapse()
    /// Messages that arrived while a sheet covered the tabs; they would not be seen under it.
    @ObservationIgnored private var waitingMessages: [DiaryToastMessage] = []
    @ObservationIgnored private var passcodeInvitationWaits = false

    // MARK: - Tabs

    func select(_ tab: Int) {
        guard tab != tabBar.selected else {
            scrollToTopCount += 1
            expandBar()
            return
        }
        tabBar.selected = tab
        expandBar()
        updateBarVisibility()
    }

    func push(_ route: AppRoute) {
        paths[tabBar.selected].append(route)
    }

    /// Each tab has its own settings and trash screens, so only that tab's path is looked at.
    func isShowing(_ route: AppRoute, inTab tab: Int) -> Bool {
        paths.indices.contains(tab) && paths[tab].contains(route)
    }

    // MARK: - Messages

    /// A sheet (the editor, sign-in, passcode setup) covers the tabs and what is shown over them.
    var isCoveredBySheet: Bool {
        editor != nil || isSigningIn || isSettingPasscode
    }

    /// Shows a short message over the tabs, or as soon as the sheet covering them has closed.
    func announce(_ title: String, message: String, duration: Double = 2.0) {
        guard !isCoveredBySheet else {
            waitingMessages.append(DiaryToastMessage(title: title, message: message, duration: duration))
            return
        }
        toasts.show(title, message: message, duration: duration)
    }

    func invitePasscodeSetup() {
        guard !isCoveredBySheet else {
            passcodeInvitationWaits = true
            return
        }
        isAskingForPasscode = true
    }

    private func showWhatWaitedForTheSheet() {
        guard !isCoveredBySheet else { return }
        // One message is shown at a time; the latest one is the one still worth reading.
        if let message = waitingMessages.last {
            waitingMessages = []
            toasts.show(message.title, message: message.message, duration: message.duration)
        }
        if passcodeInvitationWaits {
            passcodeInvitationWaits = false
            isAskingForPasscode = true
        }
    }

    /// The bar belongs to each tab's first screen; pushed screens hide it, and so does the keyboard,
    /// which the bar would otherwise ride on top of.
    func updateBarVisibility() {
        tabBar.isHidden = !paths[tabBar.selected].isEmpty || isKeyboardShown
    }

    var isKeyboardShown = false {
        didSet { updateBarVisibility() }
    }

    func expandBar() {
        collapse.expand()
        tabBar.isCollapsed = false
    }

    /// `offset` is the distance scrolled from the top of `tab`'s first screen. Only the open tab moves the bar.
    func scrolled(to offset: CGFloat, tab: Int) {
        guard tab == tabBar.selected else { return }
        collapse.scrolled(to: offset)
        if tabBar.isCollapsed != collapse.isCollapsed {
            tabBar.isCollapsed = collapse.isCollapsed
        }
    }

    // MARK: - Editor

    func write(showsUploadInList: Bool = false) {
        guard editor == nil else { return }
        editor = DiaryEditorRequest(purpose: .compose, showsUploadInList: showsUploadInList)
    }

    func read(_ entry: DiaryEntry) {
        guard editor == nil else { return }
        editor = DiaryEditorRequest(purpose: .read(entry))
    }

    func edit(_ entry: DiaryEntry) {
        guard editor == nil else { return }
        editor = DiaryEditorRequest(purpose: .edit(entry))
    }

    /// The editor is already closed when its save ends, so the result is shown over whatever is on screen.
    func saveFinished(_ report: DiarySaveReport) {
        switch report {
        case .saved:
            break
        case .savedWithMissingPhotos(let count):
            announce("사진 저장 실패", message: "글은 저장했습니다. 사진 \(count)장은 저장하지 못했습니다.")
        case .savedKeepingPhotos:
            announce("사진은 그대로 두었어요", message: "사진을 모두 불러오기 전에 저장해서 글만 저장했습니다.")
        case .failed(let isUpdate):
            announce(isUpdate ? "업데이트 실패" : "업로드 실패", message: "일기를 저장하지 못했습니다.\n잠시 후 다시 시도해주세요.")
        }
        if case .failed = report { return }
        savedCount += 1
    }
}

extension View {
    /// Reports this scroll view's position to the shell, which shrinks the tab bar while scrolling down.
    /// Before iOS 18 the position cannot be read from SwiftUI, so the bar stays at full size.
    @ViewBuilder
    func shrinksTabBar(_ shell: AppShell, tab: Int) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                shell.scrolled(to: offset, tab: tab)
            }
        } else {
            self
        }
    }
}
