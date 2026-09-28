import Observation
import SwiftUI
import UIKit

// Remove this UIKit bridge when settings and the diary detail screen migrate to SwiftUI.
@MainActor
final class TrashHostingController: UIHostingController<TrashView>, DiaryUpdateDelegate {
    private let viewModel: TrashViewModel

    init(viewModel: TrashViewModel, imageLoader: any CalendarImageLoading) {
        self.viewModel = viewModel
        super.init(rootView: TrashView(viewModel: viewModel, imageLoader: imageLoader, onSelectDiary: { _ in }))
        rootView = TrashView(viewModel: viewModel, imageLoader: imageLoader,
                             onSelectDiary: { [weak self] in self?.openDiary($0) })
        title = "휴지통"
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
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = DiaryTheme.Colors.brandUIKit
    }

    // Popping the screen ends the subscription and any automatic deletion still running.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            viewModel.stop()
        }
    }

    nonisolated func diaryDidUpdate() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.viewModel.state == .failed { self.viewModel.retry() }
        }
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
        let (title, message) = Self.text(for: notice)
        TemporaryAlert.presentTemporaryMessage(with: title, message: message, interval: 1.5, for: self)
    }

    private static func text(for notice: TrashViewModel.Notice) -> (String, String) {
        switch notice {
        case .completed(.restore, let count):
            return ("복원 완료", count == 1 ? "일기를 복원했습니다." : "일기 \(count)개를 복원했습니다.")
        case .completed(.delete, let count):
            return ("영구 삭제 완료", count == 1 ? "일기를 영구 삭제했습니다." : "일기 \(count)개를 영구 삭제했습니다.")
        case .failed(let action, let succeeded, let failed):
            let verb = action == .restore ? "복원" : "영구 삭제"
            let done = succeeded > 0 ? "\n\(succeeded)개는 \(verb)되었습니다." : ""
            return ("\(verb) 실패", "일기 \(failed)개를 \(verb)하지 못했습니다.\(done)\n잠시 후 다시 시도해주세요.")
        }
    }

    private func openDiary(_ entry: DiaryEntry) {
        guard presentedViewController == nil else { return }
        let controller = WriteDiaryVC()
        controller.enterDiary(to: .showDiary, with: entry)
        controller.delegate = self
        controller.modalPresentationStyle = .automatic
        present(controller, animated: true)
    }
}
