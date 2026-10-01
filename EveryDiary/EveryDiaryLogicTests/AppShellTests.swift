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

    // MARK: - Saving

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private let day = Date(timeIntervalSince1970: 1_790_000_000)
    private var nextDay: Date { day.addingTimeInterval(86_400) }

    func testASaveIsNotedOverTheTabsUntilItEndsAndThenSaidToBeDone() async throws {
        let shell = AppShell()
        XCTAssertNil(shell.savePhase(calendarDay: nil, calendar: calendar))
        let save = DiarySaveInProgress(id: UUID(), day: day, isNew: true)

        shell.saveStarted(save)
        XCTAssertEqual(shell.savePhase(calendarDay: nil, calendar: calendar), .saving)

        shell.saveFinished(.saved, id: save.id)
        XCTAssertTrue(shell.saves.isEmpty)
        XCTAssertEqual(shell.savePhase(calendarDay: nil, calendar: calendar), .saved)

        // The note leaves by itself.
        try await Task.sleep(for: AppShell.savedNoteDuration + .milliseconds(400))
        XCTAssertNil(shell.savePhase(calendarDay: nil, calendar: calendar))
    }

    func testAFailedSaveIsNotSaidToBeDone() {
        let shell = AppShell()
        let save = DiarySaveInProgress(id: UUID(), day: day, isNew: true)
        shell.saveStarted(save)

        shell.saveFinished(.failed(isUpdate: false), id: save.id)

        XCTAssertNil(shell.savePhase(calendarDay: nil, calendar: calendar))
        XCTAssertEqual(shell.toasts.current?.title, "업로드 실패")
    }

    func testTheCalendarShowsANewDiaryOfItsSelectedDayInPlaceInsteadOfTheNote() {
        let shell = AppShell()
        let save = DiarySaveInProgress(id: UUID(), day: day.addingTimeInterval(3_600), isNew: true)
        shell.saveStarted(save)
        shell.select(2)

        // The selected day: a placeholder row in the day's list, no note.
        XCTAssertTrue(shell.isSavingNewDiary(on: day, calendar: calendar))
        XCTAssertNil(shell.savePhase(calendarDay: day, calendar: calendar))
        shell.push(.calendarDay)
        XCTAssertNil(shell.savePhase(calendarDay: day, calendar: calendar))

        // Another day selected, or a screen where that day is not shown: the note.
        XCTAssertFalse(shell.isSavingNewDiary(on: nextDay, calendar: calendar))
        XCTAssertEqual(shell.savePhase(calendarDay: nextDay, calendar: calendar), .saving)
        shell.push(.settings)
        XCTAssertEqual(shell.savePhase(calendarDay: day, calendar: calendar), .saving)
        shell.select(1)
        XCTAssertEqual(shell.savePhase(calendarDay: day, calendar: calendar), .saving)

        // Back on the selected day the end is not noted either: the diary itself appears.
        shell.select(2)
        shell.paths[2] = []
        shell.saveFinished(.saved, id: save.id)
        XCTAssertNil(shell.savePhase(calendarDay: day, calendar: calendar))
        XCTAssertEqual(shell.savePhase(calendarDay: nextDay, calendar: calendar), .saved)
    }

    func testAnEditedDiaryIsAlwaysNotedOverTheTabs() {
        let shell = AppShell()
        shell.select(2)
        shell.saveStarted(DiarySaveInProgress(id: UUID(), day: day, isNew: false))

        // Its row is already there, so no placeholder stands in for it.
        XCTAssertFalse(shell.isSavingNewDiary(on: day, calendar: calendar))
        XCTAssertEqual(shell.savePhase(calendarDay: day, calendar: calendar), .saving)
    }

    func testTheListShowsADiaryWrittenFromItInPlace() {
        let shell = AppShell()
        let fromList = DiarySaveInProgress(id: UUID(), day: day, isNew: true, showsInList: true)
        shell.saveStarted(fromList)
        XCTAssertNil(shell.savePhase(calendarDay: nil, calendar: calendar))

        // On another tab the list's row is not seen.
        shell.select(1)
        XCTAssertEqual(shell.savePhase(calendarDay: nil, calendar: calendar), .saving)
    }

    func testWritingFromTheCalendarCarriesItsSelectedDay() {
        let shell = AppShell()
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        shell.write(on: day)
        XCTAssertEqual(shell.editor?.day, day)
    }
}
