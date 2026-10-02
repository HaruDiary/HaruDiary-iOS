import Observation
import SwiftUI

/// Screens pushed inside a tab.
enum AppRoute: Hashable {
    case settings
    case reminders
    case lock
    case textSize
    case appearance
    case trash
    /// Diaries found by their title or content; opened from the list and the calendar.
    case search
    /// All diaries as one text file to share or keep; opened from settings.
    case export
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
    /// For a new diary: the day it is for, when one was picked before opening (the calendar's selected day).
    var day: Date? = nil
}

/// A save that has not ended yet.
struct DiarySaveInProgress: Identifiable, Equatable {
    let id: UUID
    let day: Date
    let isNew: Bool
    /// The list shows a row for it while it is written from the list.
    var showsInList = false
}

enum DiarySavePhase: Equatable {
    case saving
    case saved
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

    /// Saves going on. The editor is already closed, so the tabs show them.
    private(set) var saves: [DiarySaveInProgress] = []
    /// The save that just succeeded, kept for a moment to say so.
    private(set) var justSaved: DiarySaveInProgress?
    @ObservationIgnored private var justSavedExpiry: Task<Void, Never>?
    static let savedNoteDuration: Duration = .milliseconds(1600)

    /// Goes up when a diary was saved; screens whose loading failed load again.
    private(set) var savedCount = 0
    /// Goes up when the open tab is tapped again; its first screen scrolls to the top.
    private(set) var scrollToTopCount = 0

    @ObservationIgnored private var collapse = TabBarCollapse()
    /// Messages that arrived while a sheet covered the tabs; they would not be seen under it.
    @ObservationIgnored private var waitingMessages: [DiaryToastMessage] = []
    @ObservationIgnored private var passcodeInvitationWaits = false
    @ObservationIgnored private var waiting: Task<Void, Never>?
    /// True while anything is presented over the tabs: also sheets the screens open themselves (profile editing,
    /// a web page, a month's picture, an alert). Set by the scene, which can see what its window presents.
    @ObservationIgnored var isCoveredByPresentedScreen: @MainActor () -> Bool = { false }

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

    /// Something covers the tabs and what is shown over them: a sheet of the shell or one a screen opened.
    var isCoveredBySheet: Bool {
        editor != nil || isSigningIn || isSettingPasscode || isCoveredByPresentedScreen()
    }

    /// Shows a short message over the tabs, or as soon as the sheet covering them has closed.
    func announce(_ title: String, message: String, duration: Double = 2.0) {
        guard !isCoveredBySheet else {
            waitingMessages.append(DiaryToastMessage(title: title, message: message, duration: duration))
            waitUntilUncovered()
            return
        }
        toasts.show(title, message: message, duration: duration)
    }

    func invitePasscodeSetup() {
        guard !isCoveredBySheet else {
            passcodeInvitationWaits = true
            waitUntilUncovered()
            return
        }
        isAskingForPasscode = true
    }

    /// A sheet a screen opened itself does not tell the shell when it closes, so it is looked at again shortly.
    private func waitUntilUncovered() {
        guard waiting == nil else { return }
        waiting = Task { [weak self] in
            while let self, self.isCoveredBySheet {
                try? await Task.sleep(for: .milliseconds(300))
                if Task.isCancelled { return }
            }
            self?.waiting = nil
            self?.showWhatWaitedForTheSheet()
        }
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

    func write(showsUploadInList: Bool = false, on day: Date? = nil) {
        guard editor == nil else { return }
        editor = DiaryEditorRequest(purpose: .compose, showsUploadInList: showsUploadInList, day: day)
    }

    func read(_ entry: DiaryEntry) {
        guard editor == nil else { return }
        editor = DiaryEditorRequest(purpose: .read(entry))
    }

    func edit(_ entry: DiaryEntry) {
        guard editor == nil else { return }
        editor = DiaryEditorRequest(purpose: .edit(entry))
    }

    func saveStarted(_ save: DiarySaveInProgress) {
        saves.removeAll { $0.id == save.id }
        saves.append(save)
    }

    /// A new diary being saved is shown where it will appear, when that place is on screen: the calendar's
    /// selected day (`calendarDay`), or the list for a diary written from the list.
    func showsInPlace(_ save: DiarySaveInProgress, calendarDay: Date?, calendar: Calendar) -> Bool {
        guard save.isNew else { return false }
        let path = paths[tabBar.selected]
        switch tabBar.selected {
        case 0:
            return path.isEmpty && save.showsInList
        case 2:
            guard path.isEmpty || path == [.calendarDay], let calendarDay else { return false }
            return calendar.isDate(save.day, inSameDayAs: calendarDay)
        default:
            return false
        }
    }

    /// A new diary for `day` is being saved; the calendar shows a placeholder row for it on that day.
    func isSavingNewDiary(on day: Date, calendar: Calendar) -> Bool {
        saves.contains { $0.isNew && calendar.isDate($0.day, inSameDayAs: day) }
    }

    /// The small note over the tabs: for saves whose place is not on screen. Nil when there is nothing to tell.
    func savePhase(calendarDay: Date?, calendar: Calendar) -> DiarySavePhase? {
        if saves.contains(where: { !showsInPlace($0, calendarDay: calendarDay, calendar: calendar) }) { return .saving }
        if let justSaved, !showsInPlace(justSaved, calendarDay: calendarDay, calendar: calendar) { return .saved }
        return nil
    }

    /// The editor is already closed when its save ends, so the result is shown over whatever is on screen.
    /// `id` is the save given to `saveStarted`.
    func saveFinished(_ report: DiarySaveReport, id: UUID? = nil) {
        let ended = saves.first { $0.id == id }
        saves.removeAll { $0.id == id }
        if let ended, report != .failed(isUpdate: true), report != .failed(isUpdate: false) {
            justSaved = ended
            AccessibilityNotification.Announcement("일기를 저장했어요").post()
            justSavedExpiry?.cancel()
            justSavedExpiry = Task { [weak self] in
                try? await Task.sleep(for: Self.savedNoteDuration)
                guard !Task.isCancelled, self?.justSaved?.id == ended.id else { return }
                self?.justSaved = nil
            }
        }
        switch report {
        case .saved:
            break
        case .savedWithMissingPhotos(let count):
            announce("사진 저장 실패", message: "글은 저장했습니다. 사진 \(count)장은 저장하지 못했습니다.")
        case .savedKeepingPhotos:
            announce("사진은 그대로 두었어요", message: "사진을 모두 불러오기 전에 저장해서 글만 저장했습니다.")
        case .failed(let isUpdate):
            // The writing is kept on the device, so writing or editing again brings it back.
            announce(isUpdate ? "업데이트 실패" : "업로드 실패",
                     message: isUpdate ? "일기를 저장하지 못했습니다.\n고친 내용은 남겨 두었어요. 그 일기를 다시 수정하면 이어서 고칠 수 있어요."
                                       : "일기를 저장하지 못했습니다.\n쓰던 글은 남겨 두었어요. 일기 쓰기를 누르면 이어서 쓸 수 있어요.",
                     duration: 3.5)
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
