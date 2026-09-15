import Observation
import SwiftUI
import UIKit

// Remove this UIKit navigation bridge when diary detail/editor, settings and the tab shell migrate.
@MainActor
final class CalendarHostingController: UIHostingController<CalendarView>, DiaryUpdateDelegate {
    private let viewModel: CalendarViewModel
    private let imageLoader: any CalendarImageLoading

    init(viewModel: CalendarViewModel, imageLoader: any CalendarImageLoading) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        super.init(rootView: CalendarView(
            viewModel: viewModel, imageLoader: imageLoader,
            onSelectDiary: { _ in }, onOpenDayList: {}, onWriteDiary: {}, onOpenSettings: {}
        ))
        rootView = CalendarView(
            viewModel: viewModel,
            imageLoader: imageLoader,
            onSelectDiary: { [weak self] in self?.openDiary($0) },
            onOpenDayList: { [weak self] in self?.openDayList() },
            onWriteDiary: { [weak self] in self?.openDiary(nil) },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        navigationItem.backButtonTitle = "캘린더"
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DiaryTheme.Colors.backgroundUIKit
        viewModel.start()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    nonisolated func diaryDidUpdate() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // The feature's existing listener updates both the calendar and the day list.
            if self.viewModel.state == .failed { self.viewModel.retry() }
        }
    }

    private func openDayList() {
        let controller = CalendarDayHostingController(
            viewModel: viewModel, imageLoader: imageLoader,
            onSelectDiary: { [weak self] in self?.openDiary($0) },
            onWriteDiary: { [weak self] in self?.openDiary(nil) }
        )
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }

    private func openSettings() {
        let controller = SettingVC()
        controller.hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func openDiary(_ entry: DiaryEntry?) {
        let presenter = navigationController?.topViewController ?? self
        guard presenter.presentedViewController == nil else { return }
        let controller = WriteDiaryVC()
        if let entry {
            controller.enterDiary(to: .showDiary, with: entry)
        } else {
            controller.enterDiary(to: .writeNewDiary)
        }
        controller.delegate = self
        controller.modalPresentationStyle = .automatic
        presenter.present(controller, animated: true)
    }
}

@MainActor
private final class CalendarDayHostingController: UIHostingController<CalendarDayListView> {
    private let viewModel: CalendarViewModel

    init(viewModel: CalendarViewModel, imageLoader: any CalendarImageLoading, onSelectDiary: @escaping (DiaryEntry) -> Void, onWriteDiary: @escaping () -> Void) {
        self.viewModel = viewModel
        super.init(rootView: CalendarDayListView(
            viewModel: viewModel, imageLoader: imageLoader,
            onSelectDiary: onSelectDiary, onWriteDiary: onWriteDiary
        ))
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        observeTitle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DiaryTheme.Colors.brandUIKit
    }

    private func observeTitle() {
        let formatter = DateFormatter()
        formatter.calendar = viewModel.calendar
        formatter.timeZone = viewModel.calendar.timeZone
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        title = formatter.string(from: viewModel.selectedDate)
        withObservationTracking {
            _ = viewModel.selectedDate
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeTitle() }
        }
    }
}
