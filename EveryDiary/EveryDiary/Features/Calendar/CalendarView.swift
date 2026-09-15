import SwiftUI

struct CalendarView: View {
    let viewModel: CalendarViewModel
    let imageLoader: any CalendarImageLoading
    let onSelectDiary: (DiaryEntry) -> Void
    let onOpenDayList: () -> Void
    let onWriteDiary: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DiaryTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: DiaryTheme.Spacing.section) {
                    HStack {
                        Text("캘린더").font(DiaryTheme.Fonts.title)
                        Spacer()
                        Button(action: onOpenSettings) {
                            Image(systemName: "gearshape").font(.system(size: DiaryTheme.Size.icon))
                                .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                        }
                        .accessibilityLabel("설정")
                    }
                    .foregroundStyle(DiaryTheme.Colors.brand)

                    CalendarMonthGrid(viewModel: viewModel)
                        // Keep seven date columns legible; surrounding text still follows the full accessibility size.
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    CalendarLoadStatus(viewModel: viewModel)
                    selectedDaySection
                }
                .padding(DiaryTheme.Spacing.screen)
                .padding(.bottom, DiaryTheme.Size.floatingButton + DiaryTheme.Spacing.section)
            }
            CalendarWriteButton(action: onWriteDiary)
                .padding(DiaryTheme.Spacing.screen)
        }
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
            Button(action: onOpenDayList) {
                HStack {
                    Text(dayTitle).font(DiaryTheme.Fonts.section)
                    Spacer()
                    if !viewModel.selectedEntries.isEmpty {
                        Text("전체 \(viewModel.selectedEntries.count)개")
                            .font(DiaryTheme.Fonts.caption)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                }
                .foregroundStyle(DiaryTheme.Colors.brand)
                .frame(minHeight: DiaryTheme.Size.touchTarget)
            }
            .accessibilityLabel("\(dayTitle), 날짜별 일기 보기")

            if viewModel.selectedEntries.isEmpty {
                if viewModel.state == .loaded {
                    Text("이 날짜에 작성한 일기가 없어요")
                        .font(DiaryTheme.Fonts.body)
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.thumbnail)
                }
            } else {
                ForEach(Array(viewModel.selectedEntries.prefix(2).enumerated()), id: \.offset) { _, entry in
                    Button { onSelectDiary(entry) } label: {
                        CalendarDiaryRow(entry: entry, calendar: viewModel.calendar, imageLoader: imageLoader)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = viewModel.calendar
        formatter.timeZone = viewModel.calendar.timeZone
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: viewModel.selectedDate)
    }
}

struct CalendarMonthGrid: View {
    let viewModel: CalendarViewModel
    @ScaledMetric(relativeTo: .body) private var dayHeight: CGFloat = DiaryTheme.Size.touchTarget
    @State private var isShowingDatePicker = false
    @State private var dateToSelect = Date(timeIntervalSince1970: 0)

    var body: some View {
        VStack(spacing: DiaryTheme.Spacing.medium) {
            HStack {
                Button { viewModel.moveMonth(by: -1) } label: {
                    Image(systemName: "chevron.left").frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                }
                .disabled(!viewModel.canMoveToPreviousMonth)
                .accessibilityLabel("이전 달")
                Spacer()
                Button {
                    dateToSelect = viewModel.selectedDate
                    isShowingDatePicker = true
                } label: {
                    Text(monthTitle).font(DiaryTheme.Fonts.title)
                        .frame(minHeight: DiaryTheme.Size.touchTarget)
                }
                .accessibilityLabel("\(monthTitle), 날짜로 이동")
                Spacer()
                Button { viewModel.moveMonth(by: 1) } label: {
                    Image(systemName: "chevron.right").frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                }
                .accessibilityLabel("다음 달")
            }
            .foregroundStyle(DiaryTheme.Colors.brand)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: DiaryTheme.Spacing.small) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(DiaryTheme.Fonts.caption)
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                }
                if let month = viewModel.month {
                    ForEach(Array(month.cells.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayButton(date)
                        } else {
                            Color.clear.frame(height: dayHeight + DiaryTheme.Spacing.small)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingDatePicker) {
            NavigationStack {
                Group {
                    if let minimumDate = viewModel.calendar.date(from: DateComponents(year: 2011, month: 1, day: 1)) {
                        DatePicker("날짜 선택", selection: $dateToSelect, in: minimumDate..., displayedComponents: .date)
                    } else {
                        DatePicker("날짜 선택", selection: $dateToSelect, displayedComponents: .date)
                    }
                }
                .datePickerStyle(.graphical)
                .padding(DiaryTheme.Spacing.screen)
                .navigationTitle("날짜로 이동")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { isShowingDatePicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("이동") {
                            viewModel.select(dateToSelect)
                            isShowingDatePicker = false
                        }
                    }
                }
            }
            .environment(\.calendar, viewModel.calendar)
            .environment(\.timeZone, viewModel.calendar.timeZone)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .tint(DiaryTheme.Colors.brand)
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let day = CalendarDay(date: date, calendar: viewModel.calendar)
        let isSelected = day == viewModel.selectedDay
        let hasDiary = viewModel.index.decoratedDays.contains(day)
        return Button { viewModel.select(date) } label: {
            VStack(spacing: 4) {
                Text("\(day.day)")
                    .font(DiaryTheme.Fonts.body.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(isSelected ? DiaryTheme.Colors.surface : DiaryTheme.Colors.text)
                    .frame(maxWidth: .infinity, minHeight: dayHeight)
                    .background {
                        if isSelected { Circle().fill(DiaryTheme.Colors.brand) }
                    }
                Circle().fill(hasDiary ? DiaryTheme.Colors.brand : .clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.year)년 \(day.month)월 \(day.day)일\(hasDiary ? ", 일기 있음" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = viewModel.calendar
        formatter.locale = Locale(identifier: "ko_KR")
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        let offset = viewModel.calendar.firstWeekday - 1
        return Array(symbols.dropFirst(offset)) + Array(symbols.prefix(offset))
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = viewModel.calendar
        formatter.timeZone = viewModel.calendar.timeZone
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: viewModel.displayedMonth)
    }
}

struct CalendarLoadStatus: View {
    let viewModel: CalendarViewModel

    var body: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("일기를 불러오는 중이에요")
                .frame(maxWidth: .infinity)
        case .failed:
            VStack(spacing: DiaryTheme.Spacing.small) {
                Text("일기를 불러오지 못했어요")
                    .foregroundStyle(DiaryTheme.Colors.error)
                Button("다시 시도") { viewModel.retry() }
                    .tint(DiaryTheme.Colors.brand)
                    .frame(minHeight: DiaryTheme.Size.touchTarget)
            }
            .font(DiaryTheme.Fonts.body)
            .frame(maxWidth: .infinity)
        case .loaded:
            EmptyView()
        }
    }
}

struct CalendarWriteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: DiaryTheme.Size.icon))
                .foregroundStyle(DiaryTheme.Colors.surface)
                .frame(width: DiaryTheme.Size.floatingButton, height: DiaryTheme.Size.floatingButton)
                .background(DiaryTheme.Colors.brand, in: Circle())
                .shadow(color: DiaryTheme.Colors.brand.opacity(0.2), radius: 8, y: 4)
        }
        .accessibilityLabel("일기 작성")
    }
}
