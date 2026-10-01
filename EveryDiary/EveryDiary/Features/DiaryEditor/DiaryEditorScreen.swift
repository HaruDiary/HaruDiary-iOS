import PhotosUI
import SwiftUI

/// The editor as a sheet: writing a new diary, or reading or editing a stored one.
struct DiaryEditorScreen: View {
    @State private var model: Once<DiaryEditorViewModel>
    @State private var toasts = DiaryToastCenter()
    @State private var isPickingPhotos = false
    @State private var pickerItems: [PhotosPickerItem] = []
    /// The selection already in the editor, so an unchanged picker result is not loaded again.
    @State private var handledIDs: [String] = []
    @Environment(\.dismiss) private var dismiss

    /// `onSaveStarted` and `onSaveFinished` are called even after the sheet has closed: saving goes on without it.
    init(request: DiaryEditorRequest, saver: any DiarySaving,
         onSaveStarted: @escaping () -> Void, onSaveFinished: @escaping (DiarySaveReport) -> Void) {
        _model = State(initialValue: Once {
            let viewModel = DiaryEditorModule.makeViewModel(saver: saver)
            viewModel.onSaveStarted = onSaveStarted
            viewModel.onSaveFinished = onSaveFinished
            switch request.purpose {
            case .compose: viewModel.startComposing()
            case .read(let entry): viewModel.open(entry, editing: false)
            case .edit(let entry): viewModel.open(entry, editing: true)
            }
            return viewModel
        })
    }

    private var viewModel: DiaryEditorViewModel { model.value }

    var body: some View {
        DiaryEditorView(viewModel: viewModel, actions: DiaryEditorActions(
            close: { dismiss() },
            save: {
                // The save continues after the editor closes; the view model lives until it ends.
                if viewModel.save() { dismiss() }
            },
            pickPhotos: pickPhotos
        ))
        // Unsaved writing is not lost to a swipe down; the close button asks first.
        .interactiveDismissDisabled(viewModel.hasChanges || viewModel.isSaving)
        // Up to three photos in selection order, with the photos already in the diary shown as selected.
        .photosPicker(isPresented: $isPickingPhotos, selection: $pickerItems, maxSelectionCount: max(viewModel.pickerLimit, 1),
                      selectionBehavior: .ordered, matching: .images, photoLibrary: .shared())
        .onChange(of: pickerItems) { pickerChanged() }
        .onChange(of: isPickingPhotos) { _, isPicking in
            if !isPicking { pickerChanged() }
        }
        .onChange(of: viewModel.notice) { _, notice in
            guard let notice else { return }
            viewModel.notice = nil
            show(notice)
        }
        .diaryToast(toasts)
    }

    private func pickPhotos() {
        guard viewModel.canPickPhotos() else { return }
        Task {
            await DiaryPhotoLoader.requestLibraryAccessIfNeeded()
            let selection = viewModel.pickerSelection
            handledIDs = selection
            pickerItems = selection.map { PhotosPickerItem(itemIdentifier: $0) }
            isPickingPhotos = true
        }
    }

    private func pickerChanged() {
        let ids = pickerItems.compactMap(\.itemIdentifier)
        guard ids != handledIDs else { return }
        handledIDs = ids
        // Photos already in the editor keep their place; only the newly picked ones are loaded.
        let current = Set(viewModel.pickerSelection)
        let newItems = pickerItems.filter { item in item.itemIdentifier.map { !current.contains($0) } ?? false }
        viewModel.pickingStarted(pickedIDs: ids)
        Task {
            let photos = await DiaryPhotoLoader.load(newItems)
            viewModel.finishPicking(photos, pickedIDs: ids)
        }
    }

    private func show(_ notice: DiaryEditorViewModel.Notice) {
        switch notice {
        case .titleMissing:
            toasts.show("빈 제목", message: "제목이 비어있습니다. 제목을 입력해주세요.")
        case .photosStillLoading:
            toasts.show("사진을 불러오는 중", message: "사진을 다 불러온 뒤 다시 시도해주세요.")
        case .photosNotLoaded(let count):
            toasts.show("사진을 불러오지 못했어요", message: "사진 \(count)장을 읽을 수 없어 넣지 못했어요.\niCloud 사진은 내려받은 뒤 다시 골라주세요.", duration: 3.0)
        case .photoLimitReached:
            toasts.show("사진은 3장까지", message: "사진을 지운 뒤 다시 추가해주세요.")
        case .signInRequired:
            toasts.show("로그인 필요", message: "일기를 연 계정으로 다시 로그인해주세요.")
        }
    }
}
