import SwiftUI

struct CalendarView: View {
    let viewModel: CalendarViewModel
    let imageLoader: any CalendarImageLoading
    let onSelectDiary: (DiaryEntry) -> Void
    let onOpenDayList: () -> Void
    let onWriteDiary: () -> Void
    let onOpenSettings: () -> Void
    var tabRoot: TabRoot? = nil
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            DiaryTheme.Colors.background.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DiaryTheme.Spacing.section) {
                        DiaryTabHeader(title: "캘린더", onOpenSettings: onOpenSettings)

                        CalendarMonthGrid(viewModel: viewModel)
                            // Keep seven date columns legible; surrounding text still follows the full accessibility size.
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        CalendarLoadStatus(viewModel: viewModel)
                        selectedDaySection
                    }
                    .padding(DiaryTheme.Spacing.screen)
                    .padding(.bottom, DiaryTheme.Size.floatingButtonClearance)
                    // The whole content, so scrolling to the top also restores the space above the title.
                    .id(TabRoot.topID)
                }
                .tabRoot(tabRoot, proxy: proxy)
            }
            DiaryWriteButton(action: onWriteDiary)
        }
        .diaryStatusBarBackground()
        // The today marker follows the date: at midnight, on return to the app and when the tab is shown again.
        .onAppear { viewModel.refreshToday() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshToday() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { @MainActor in viewModel.refreshToday() }
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
    @State private var isShowingYear = false
    /// Which way the month last moved: a later month slides in from the right, an earlier one from the left.
    @State private var movesForward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DiaryTheme.Spacing.medium) {
            HStack {
                Button { move(forward: false) { viewModel.moveMonth(by: -1) } } label: {
                    Image(systemName: "chevron.left").frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                }
                .disabled(!viewModel.canMoveToPreviousMonth)
                .accessibilityLabel("이전 달")
                Spacer()
                Button { isShowingYear = true } label: {
                    HStack(spacing: 4) {
                        Text(monthTitle).font(DiaryTheme.Fonts.title)
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: !movesForward))
                        // Says the title opens something: the year overview.
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }
                    .frame(minHeight: DiaryTheme.Size.touchTarget)
                }
                .accessibilityLabel("\(monthTitle), 다른 달 고르기")
                Spacer()
                Button { move(forward: true) { viewModel.moveMonth(by: 1) } } label: {
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
            }
            // The weekday row stays; only the days of the month slide.
            ZStack(alignment: .top) {
                if let month = viewModel.month {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: DiaryTheme.Spacing.small) {
                        ForEach(Array(month.cells.enumerated()), id: \.offset) { _, date in
                            if let date {
                                dayButton(date)
                            } else {
                                Color.clear.frame(height: dayHeight + DiaryTheme.Spacing.small)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .id(viewModel.displayedMonth)
                    .transition(monthTransition)
                }
            }
            .clipped()
        }
        .sheet(isPresented: $isShowingYear) {
            CalendarYearSheet(viewModel: viewModel) { year, month in
                isShowingYear = false
                guard let target = viewModel.calendar.date(from: DateComponents(year: year, month: month ?? viewModel.today.month, day: 1)) else { return }
                move(forward: target >= viewModel.displayedMonth) {
                    if let month { viewModel.showMonth(year: year, month: month) } else { viewModel.showToday() }
                }
            }
        }
    }

    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movesForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movesForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    /// The direction is set one step before the month changes, so the month leaving also knows which way to go.
    private func move(forward: Bool, _ change: @escaping () -> Void) {
        movesForward = forward
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.3), change)
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let day = CalendarDay(date: date, calendar: viewModel.calendar)
        let isSelected = day == viewModel.selectedDay
        let isToday = day == viewModel.today
        let hasDiary = viewModel.index.decoratedDays.contains(day)
        return Button { viewModel.select(date) } label: {
            VStack(spacing: 4) {
                Text("\(day.day)")
                    .font(DiaryTheme.Fonts.body.weight(isSelected || isToday ? .bold : .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(isSelected ? DiaryTheme.Colors.surface : isToday ? DiaryTheme.Colors.brand : DiaryTheme.Colors.text)
                    .frame(maxWidth: .infinity, minHeight: dayHeight)
                    .background {
                        if isSelected {
                            Circle().fill(DiaryTheme.Colors.brand)
                        } else if isToday {
                            // Today keeps a ring wherever the selection is.
                            Circle().strokeBorder(DiaryTheme.Colors.brand, lineWidth: 1.5)
                        }
                    }
                Circle().fill(hasDiary ? DiaryTheme.Colors.brand : .clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isToday ? "오늘, " : "")\(day.year)년 \(day.month)월 \(day.day)일\(hasDiary ? ", 일기 있음" : "")")
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

/// A whole year at a glance: pick a month to go straight to it. Opened from the month title.
struct CalendarYearSheet: View {
    let viewModel: CalendarViewModel
    /// The picked year and month; a nil month means today.
    let onPick: (Int, Int?) -> Void
    @State private var year: Int

    init(viewModel: CalendarViewModel, onPick: @escaping (Int, Int?) -> Void) {
        self.viewModel = viewModel
        self.onPick = onPick
        _year = State(initialValue: viewModel.calendar.component(.year, from: viewModel.displayedMonth))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DiaryTheme.Spacing.medium), count: 3)

    var body: some View {
        let shownYear = viewModel.calendar.component(.year, from: viewModel.displayedMonth)
        let shownMonth = viewModel.calendar.component(.month, from: viewModel.displayedMonth)
        let today = viewModel.today
        let written = viewModel.monthsWithDiaries(in: year)
        VStack(spacing: DiaryTheme.Spacing.section) {
            HStack {
                Button { withAnimation(.easeInOut(duration: 0.2)) { year -= 1 } } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                }
                .disabled(year <= CalendarViewModel.minimumYear)
                .accessibilityLabel("이전 해")
                Spacer()
                Text("\(String(year))년")
                    .font(DiaryTheme.Fonts.title)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { withAnimation(.easeInOut(duration: 0.2)) { year += 1 } } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                }
                .accessibilityLabel("다음 해")
            }
            .foregroundStyle(DiaryTheme.Colors.brand)
            .padding(.top, DiaryTheme.Spacing.section)

            LazyVGrid(columns: columns, spacing: DiaryTheme.Spacing.medium) {
                ForEach(1...12, id: \.self) { month in
                    let isShown = year == shownYear && month == shownMonth
                    let isThisMonth = year == today.year && month == today.month
                    Button { onPick(year, month) } label: {
                        VStack(spacing: 4) {
                            Text("\(month)월")
                                .font(.body.weight(isShown || isThisMonth ? .bold : .regular))
                                .foregroundStyle(isShown ? DiaryTheme.Colors.surface : isThisMonth ? DiaryTheme.Colors.brand : DiaryTheme.Colors.text)
                            Circle()
                                .fill(written.contains(month) ? (isShown ? DiaryTheme.Colors.surface : DiaryTheme.Colors.brand) : .clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background {
                            if isShown {
                                RoundedRectangle(cornerRadius: DiaryTheme.Radius.card).fill(DiaryTheme.Colors.brand)
                            } else {
                                RoundedRectangle(cornerRadius: DiaryTheme.Radius.card).fill(DiaryTheme.Colors.surface)
                            }
                        }
                        .overlay {
                            if isThisMonth && !isShown {
                                RoundedRectangle(cornerRadius: DiaryTheme.Radius.card)
                                    .strokeBorder(DiaryTheme.Colors.brand, lineWidth: 1.5)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(String(year))년 \(month)월\(isThisMonth ? ", 이번 달" : "")\(written.contains(month) ? ", 일기 있음" : "")")
                    .accessibilityAddTraits(isShown ? .isSelected : [])
                }
            }
            Button { onPick(today.year, nil) } label: {
                Text("오늘로 가기")
                    .font(.headline)
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .frame(maxWidth: .infinity, minHeight: DiaryTheme.Size.touchTarget)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DiaryTheme.Spacing.screen)
        .background(DiaryTheme.Colors.background)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}
