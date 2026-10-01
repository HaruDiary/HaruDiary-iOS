import XCTest

@MainActor
final class AppShellTests: XCTestCase {
    func testTappingTheOpenTabAsksItToScrollToTopAndAnotherTabOnlySwitches() {
        let shell = AppShell()
        XCTAssertEqual(shell.tabBar.selected, 0)

        shell.select(2)
        XCTAssertEqual(shell.tabBar.selected, 2)
        XCTAssertEqual(shell.scrollToTopCount, 0, "Switching tabs does not scroll anything")

        shell.select(2)
        XCTAssertEqual(shell.scrollToTopCount, 1)
        XCTAssertEqual(shell.tabBar.selected, 2, "Screens compare this with their own tab, so only the open one scrolls")
    }

    func testOnlyTheOpenTabShrinksTheBar() {
        let shell = AppShell()
        shell.scrolled(to: 0, tab: 2)
        shell.scrolled(to: 400, tab: 2)
        XCTAssertFalse(shell.tabBar.isCollapsed, "A tab kept alive behind the open one is ignored")

        shell.scrolled(to: 0, tab: 0)
        shell.scrolled(to: 400, tab: 0)
        XCTAssertTrue(shell.tabBar.isCollapsed)

        shell.select(1)
        XCTAssertFalse(shell.tabBar.isCollapsed, "A newly opened tab starts with the full bar")
    }

    func testBarHidesOnPushedScreensAndUnderTheKeyboard() {
        let shell = AppShell()
        shell.push(.settings)
        shell.updateBarVisibility()
        XCTAssertTrue(shell.tabBar.isHidden)
        XCTAssertTrue(shell.isShowing(.settings, inTab: 0))

        shell.select(1)
        XCTAssertFalse(shell.tabBar.isHidden, "The other tab is on its first screen")
        shell.isKeyboardShown = true
        XCTAssertTrue(shell.tabBar.isHidden)
        shell.isKeyboardShown = false
        XCTAssertFalse(shell.tabBar.isHidden)

        shell.select(0)
        XCTAssertTrue(shell.tabBar.isHidden, "The first tab still shows settings")
    }

    func testSaveResultIsAnnouncedAndOnlySuccessRefreshesScreens() {
        let shell = AppShell()
        shell.saveFinished(.saved)
        XCTAssertEqual(shell.savedCount, 1)
        XCTAssertNil(shell.toasts.current)

        shell.saveFinished(.savedWithMissingPhotos(2))
        XCTAssertEqual(shell.savedCount, 2)
        XCTAssertEqual(shell.toasts.current?.title, "사진 저장 실패")

        shell.saveFinished(.failed(isUpdate: true))
        XCTAssertEqual(shell.savedCount, 2)
        XCTAssertEqual(shell.toasts.current?.title, "업데이트 실패")
    }

    func testSettingsOpenInTwoTabsAreToldApart() {
        let shell = AppShell()
        shell.push(.settings)
        shell.select(2)
        shell.push(.settings)
        shell.push(.trash)

        // Leaving the calendar tab's settings: the list tab's settings must not keep it "showing".
        shell.paths[2] = []
        XCTAssertFalse(shell.isShowing(.settings, inTab: 2))
        XCTAssertFalse(shell.isShowing(.trash, inTab: 2))
        XCTAssertTrue(shell.isShowing(.settings, inTab: 0))
    }

    func testMessagesWaitUntilTheSheetOverTheTabsCloses() {
        let shell = AppShell()
        shell.write()
        shell.announce("앱 잠금을 껐어요", message: "설정에서 새 암호를 정할 수 있어요.")
        shell.invitePasscodeSetup()
        XCTAssertNil(shell.toasts.current, "Under the editor sheet nobody would see it")
        XCTAssertFalse(shell.isAskingForPasscode)

        shell.editor = nil
        XCTAssertEqual(shell.toasts.current?.title, "앱 잠금을 껐어요")
        XCTAssertTrue(shell.isAskingForPasscode)

        shell.announce("삭제 완료", message: "휴지통으로 이동하였습니다.")
        XCTAssertEqual(shell.toasts.current?.title, "삭제 완료", "Shown at once when nothing covers the tabs")
    }

    func testMessagesAlsoWaitForSheetsTheScreensOpenThemselves() async throws {
        let shell = AppShell()
        var profileSheetIsOpen = true
        shell.isCoveredByPresentedScreen = { profileSheetIsOpen }

        shell.announce("앱 잠금을 껐어요", message: "설정에서 새 암호를 정할 수 있어요.")
        shell.invitePasscodeSetup()
        XCTAssertNil(shell.toasts.current)
        XCTAssertFalse(shell.isAskingForPasscode)

        profileSheetIsOpen = false
        for _ in 0..<300 where shell.toasts.current == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(shell.toasts.current?.title, "앱 잠금을 껐어요", "Shown soon after the sheet closed")
        XCTAssertTrue(shell.isAskingForPasscode)
    }

    func testOnlyOneEditorOpensAtATime() {
        let shell = AppShell()
        shell.write(showsUploadInList: true)
        let first = shell.editor?.id
        XCTAssertNotNil(first)
        shell.write()
        XCTAssertEqual(shell.editor?.id, first, "A second tap while the sheet is opening is ignored")
        XCTAssertEqual(shell.editor?.showsUploadInList, true)
        XCTAssertNil(shell.editor?.day)
    }

    func testWritingFromTheCalendarCarriesItsSelectedDay() {
        let shell = AppShell()
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        shell.write(on: day)
        XCTAssertEqual(shell.editor?.day, day)
    }
}
