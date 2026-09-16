import SwiftUI

struct CalendarDayListView: View {
    let viewModel: CalendarViewModel
    let imageLoader: any CalendarImageLoading
    let onSelectDiary: (DiaryEntry) -> Void
    let onWriteDiary: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DiaryTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
                    CalendarLoadStatus(viewModel: viewModel)
                    Text("일기 \(viewModel.selectedEntries.count)개")
                        .font(DiaryTheme.Fonts.caption)
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    if viewModel.selectedEntries.isEmpty && viewModel.state == .loaded {
                        ContentUnavailableView("작성한 일기가 없어요", systemImage: "book.closed", description: Text("이 날짜의 기록이 여기에 표시돼요"))
                    }
                    ForEach(Array(viewModel.selectedEntries.enumerated()), id: \.offset) { _, entry in
                        Button { onSelectDiary(entry) } label: {
                            CalendarDiaryRow(entry: entry, calendar: viewModel.calendar, imageLoader: imageLoader)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DiaryTheme.Spacing.screen)
                .padding(.bottom, DiaryTheme.Size.floatingButton + DiaryTheme.Spacing.section)
            }
            CalendarWriteButton(action: onWriteDiary).padding(DiaryTheme.Spacing.screen)
        }
    }
}
