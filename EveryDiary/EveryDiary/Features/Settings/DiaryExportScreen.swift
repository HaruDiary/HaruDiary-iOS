import SwiftUI

/// Settings › 일기 내보내기: every diary as one text file, handed to the system share sheet.
struct DiaryExportScreen: View {
    @State private var model: Once<DiaryExportViewModel>

    init(makeViewModel: @escaping @MainActor () -> DiaryExportViewModel) {
        _model = State(initialValue: Once(makeViewModel))
    }

    var body: some View {
        let viewModel = model.value
        ScrollView {
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.section) {
                VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
                    Label("일기를 파일로 내보내요", systemImage: "doc.text")
                        .font(DiaryTheme.Fonts.section)
                        .foregroundStyle(DiaryTheme.Colors.brand)
                    Text("지금까지 쓴 일기를 날짜 순서대로 텍스트 파일 하나에 담아요. 파일 앱에 저장하거나 다른 앱으로 보낼 수 있어요.")
                    Text("사진은 파일에 들어가지 않고, 휴지통에 있는 일기는 빠져요.")
                }
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.text)

                content(viewModel)
            }
            .padding(DiaryTheme.Spacing.screen)
        }
        .background(DiaryTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("일기 내보내기")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    @ViewBuilder
    private func content(_ viewModel: DiaryExportViewModel) -> some View {
        switch viewModel.state {
        case .loading:
            ProgressView("일기를 모으는 중이에요")
                .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.thumbnail)
        case .empty:
            Text("내보낼 일기가 아직 없어요")
                .font(DiaryTheme.Fonts.body)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.thumbnail)
        case .failed:
            VStack(spacing: DiaryTheme.Spacing.small) {
                Text("일기를 모으지 못했어요")
                    .foregroundStyle(DiaryTheme.Colors.error)
                Button("다시 시도") { viewModel.retry() }
                    .tint(DiaryTheme.Colors.brand)
                    .frame(minHeight: DiaryTheme.Size.touchTarget)
            }
            .font(DiaryTheme.Fonts.body)
            .frame(maxWidth: .infinity)
        case .ready(let file, let diaryCount):
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
                Text("일기 \(diaryCount)개")
                    .font(DiaryTheme.Fonts.section)
                    .foregroundStyle(DiaryTheme.Colors.text)
                Text(file.lastPathComponent)
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
                ShareLink(item: file) {
                    Label("파일 내보내기", systemImage: "square.and.arrow.up")
                        .font(DiaryTheme.Fonts.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(DiaryTheme.Colors.brand, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
                }
            }
            .padding(DiaryTheme.Spacing.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
        }
    }
}
