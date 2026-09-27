import Observation
import SwiftUI
import UIKit

// Remove this UIKit navigation bridge when diary detail/editor, settings and the tab shell migrate.
@MainActor
final class DiaryListHostingController: UIHostingController<DiaryListView>, DiaryUpdateDelegate, WriteDiaryDelegate {
    private let viewModel: DiaryListViewModel

    init(viewModel: DiaryListViewModel, imageLoader: any CalendarImageLoading) {
        self.viewModel = viewModel
        super.init(rootView: DiaryListView(
            viewModel: viewModel, imageLoader: imageLoader,
            onSelectDiary: { _ in }, onEditDiary: { _ in }, onWriteDiary: {}, onOpenSettings: {}
        ))
        rootView = DiaryListView(
            viewModel: viewModel,
            imageLoader: imageLoader,
            onSelectDiary: { [weak self] in self?.openEditor(.showDiary, with: $0) },
            onEditDiary: { [weak self] in self?.openEditor(.editDiary, with: $0) },
            onWriteDiary: { [weak self] in self?.openEditor(.writeNewDiary, with: nil) },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        navigationItem.backButtonTitle = "나의 일기"
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DiaryTheme.Colors.backgroundUIKit
        viewModel.start()
        observeNotice()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    nonisolated func diaryDidUpdate() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // The live subscription already reflects saved changes; only recover a failed load.
            if self.viewModel.state == .failed { self.viewModel.retry() }
        }
    }

    nonisolated func diaryUploadDidStart() {
        Task { @MainActor [weak self] in self?.viewModel.uploadDidStart() }
    }

    nonisolated func diaryUploadDidFinish() {
        Task { @MainActor [weak self] in self?.viewModel.uploadDidFinish() }
    }

    private func observeNotice() {
        withObservationTracking {
            _ = viewModel.notice
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.showNoticeIfNeeded()
                self?.observeNotice()
            }
        }
        showNoticeIfNeeded()
    }

    // Reuses the existing short-lived confirmation until the dialog design is migrated.
    private func showNoticeIfNeeded() {
        guard let notice = viewModel.notice else { return }
        viewModel.notice = nil
        switch notice {
        case .movedToTrash:
            TemporaryAlert.presentTemporaryMessage(with: "삭제 완료", message: "휴지통으로 이동하였습니다.", interval: 1.0, for: self)
        case .trashFailed:
            TemporaryAlert.presentTemporaryMessage(with: "삭제 실패", message: "휴지통으로 이동하지 못했습니다.\n잠시 후 다시 시도해주세요.", interval: 1.5, for: self)
        }
    }

    private func openSettings() {
        let controller = SettingVC()
        controller.hidesBottomBarWhenPushed = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func openEditor(_ status: UIstatus, with entry: DiaryEntry?) {
        guard presentedViewController == nil else { return }
        let controller = WriteDiaryVC()
        controller.enterDiary(to: status, with: entry)
        controller.delegate = self
        // Same as the previous list: only a new diary reports upload progress back to the list.
        if status == .writeNewDiary {
            controller.loadingDiaryDelegate = self
        }
        controller.modalPresentationStyle = .automatic
        present(controller, animated: true)
    }
}
