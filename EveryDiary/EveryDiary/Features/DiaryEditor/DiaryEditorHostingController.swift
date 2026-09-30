import Observation
import SwiftUI
import UIKit

protocol WriteDiaryDelegate: AnyObject {
    func diaryUploadDidStart()
    func diaryUploadDidFinish()
}

/// Why the editor is opened.
enum UIstatus {
    case writeNewDiary
    case editDiary
    case showDiary
}

typealias MakeWriteDiary = @MainActor () -> DiaryEditorHostingController

// Remove this UIKit bridge when the screens that open the editor present it from SwiftUI.
/// Presents the SwiftUI editor with the previous editor's interface, so the screens that open it are unchanged.
@MainActor
final class DiaryEditorHostingController: UIHostingController<DiaryEditorView>, UIAdaptivePresentationControllerDelegate {
    weak var delegate: DiaryUpdateDelegate? {
        didSet { bindSaveReports() }
    }
    /// Told when a save starts and ends (the list shows its upload progress).
    weak var loadingDiaryDelegate: WriteDiaryDelegate? {
        didSet { bindSaveReports() }
    }

    private let viewModel: DiaryEditorViewModel
    private let photoPicker = DiaryPhotoLibraryPicker()

    init(viewModel: DiaryEditorViewModel) {
        self.viewModel = viewModel
        let placeholder = DiaryEditorActions(close: {}, save: {}, pickPhotos: {})
        super.init(rootView: DiaryEditorView(viewModel: viewModel, actions: placeholder))
        rootView = DiaryEditorView(viewModel: viewModel, actions: DiaryEditorActions(
            close: { [weak self] in self?.dismiss(animated: true) },
            save: { [weak self] in self?.save() },
            pickPhotos: { [weak self] in self?.pickPhotos() }
        ))
        bindSaveReports()
    }

    required init?(coder: NSCoder) { return nil }

    func enterDiary(to status: UIstatus, with diary: DiaryEntry? = nil) {
        switch (status, diary) {
        case (.writeNewDiary, _): viewModel.startComposing()
        case (.editDiary, let diary?): viewModel.open(diary, editing: true)
        case (.showDiary, let diary?): viewModel.open(diary, editing: false)
        default: break
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DiaryTheme.Colors.backgroundUIKit
        observeChanges()
        observeNotice()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presentationController?.delegate = self
    }

    // MARK: - Saving

    private func save() {
        view.endEditing(true)
        // The save continues after the editor closes; the view model is kept alive until it ends.
        if viewModel.save() {
            dismiss(animated: true)
        }
    }

    /// Reports go to the screens that opened the editor, not to the editor, which is already closed.
    private func bindSaveReports() {
        viewModel.onSaveStarted = { [weak loading = loadingDiaryDelegate] in
            loading?.diaryUploadDidStart()
        }
        viewModel.onSaveFinished = { [weak update = delegate, weak loading = loadingDiaryDelegate] report in
            Self.announce(report)
            if case .failed = report {} else {
                update?.diaryDidUpdate()
            }
            loading?.diaryUploadDidFinish()
        }
    }

    private static func announce(_ report: DiarySaveReport) {
        switch report {
        case .saved:
            break
        case .savedWithMissingPhotos(let count):
            TemporaryAlert.presentOnTopScreen(with: "사진 저장 실패", message: "글은 저장했습니다. 사진 \(count)장은 저장하지 못했습니다.",
                                              interval: 2.0)
        case .savedKeepingPhotos:
            TemporaryAlert.presentOnTopScreen(with: "사진은 그대로 두었어요", message: "사진을 모두 불러오기 전에 저장해서 글만 저장했습니다.",
                                              interval: 2.0)
        case .failed(let isUpdate):
            TemporaryAlert.presentOnTopScreen(with: isUpdate ? "업데이트 실패" : "업로드 실패",
                                              message: "일기를 저장하지 못했습니다.\n잠시 후 다시 시도해주세요.", interval: 2.0)
        }
    }

    // MARK: - Photos

    private func pickPhotos() {
        guard viewModel.canPickPhotos() else { return }
        photoPicker.pick(from: self, selection: viewModel.pickerSelection, limit: viewModel.pickerLimit,
                         onStart: { [weak self] ids in self?.viewModel.pickingStarted(pickedIDs: ids) },
                         onFinish: { [weak self] photos, ids in self?.viewModel.finishPicking(photos, pickedIDs: ids) })
    }

    // MARK: - Closing

    /// A swipe down asks first when there is something unsaved, like the close button.
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        viewModel.showsDiscardConfirmation = true
    }

    private func observeChanges() {
        withObservationTracking {
            isModalInPresentation = viewModel.hasChanges || viewModel.isSaving
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeChanges() }
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

    private func showNoticeIfNeeded() {
        guard let notice = viewModel.notice, presentedViewController == nil else { return }
        viewModel.notice = nil
        switch notice {
        case .titleMissing:
            TemporaryAlert.presentTemporaryMessage(with: "빈 제목", message: "제목이 비어있습니다. 제목을 입력해주세요.", interval: 2.0, for: self)
        case .photosStillLoading:
            TemporaryAlert.presentTemporaryMessage(with: "사진을 불러오는 중", message: "사진을 다 불러온 뒤 다시 추가해주세요.", interval: 2.0, for: self)
        case .photoLimitReached:
            TemporaryAlert.presentTemporaryMessage(with: "사진은 3장까지", message: "사진을 지운 뒤 다시 추가해주세요.", interval: 2.0, for: self)
        case .signInRequired:
            TemporaryAlert.presentTemporaryMessage(with: "로그인 필요", message: "일기를 연 계정으로 다시 로그인해주세요.", interval: 2.0, for: self)
        }
    }
}
