import SwiftUI

/// The trash inside settings' navigation stack.
struct TrashScreen: View {
    let shell: AppShell
    @State private var module: Once<TrashModule>

    init(shell: AppShell, makeModule: @escaping @MainActor () -> TrashModule) {
        self.shell = shell
        _module = State(initialValue: Once(makeModule))
    }

    private var viewModel: TrashViewModel { module.value.viewModel }

    var body: some View {
        TrashView(viewModel: viewModel, imageLoader: module.value.imageLoader, onSelectDiary: { shell.read($0) })
            .navigationTitle("휴지통")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.start() }
            .onDisappear {
                // Leaving the trash ends the subscription and any automatic deletion still running.
                if !shell.isShowing(.trash) { viewModel.stop() }
            }
            .onChange(of: viewModel.notice) { _, notice in
                guard let notice else { return }
                viewModel.notice = nil
                let text = Self.text(for: notice)
                shell.toasts.show(text.title, message: text.message, duration: 1.5)
            }
            .onChange(of: shell.savedCount) {
                // The subscription already shows saved changes; only a failed load starts again.
                if viewModel.state == .failed { viewModel.retry() }
            }
    }

    private static func text(for notice: TrashViewModel.Notice) -> (title: String, message: String) {
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
}
