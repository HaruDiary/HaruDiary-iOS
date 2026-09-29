import SwiftUI

/// Every year as a full-screen photo card of its city; swiping up brings the previous year's card.
struct JourneyYearsView: View {
    let viewModel: JourneyViewModel
    let onSelectYear: (Int) -> Void

    /// The card on screen; only it animates, so the cards above and below cost nothing.
    @State private var visibleYear: Int?

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.years, id: \.self) { year in
                        Button { onSelectYear(year) } label: {
                            JourneyYearPhotoCard(progress: viewModel.progress(ofYear: year), months: months(of: year),
                                                 isAnimating: year == (visibleYear ?? viewModel.years.first))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DiaryTheme.Spacing.screen)
                        .padding(.vertical, DiaryTheme.Spacing.medium)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            // Each card snaps into place, one year per swipe.
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $visibleYear)
            .scrollIndicators(.hidden)
            .clipped()
        }
        .background(DiaryTheme.Colors.background.ignoresSafeArea())
    }

    private func months(of year: Int) -> [JourneyYearPhotoCard.Month] {
        (1...12).map { month in
            JourneyYearPhotoCard.Month(month: month, litCount: viewModel.month(year: year, month: month).days.count,
                                       numberOfDays: viewModel.numberOfDays(year: year, month: month),
                                       isUpcoming: viewModel.isUpcoming(year: year, month: month))
        }
    }
}

/// One year's city filling the card, with the year, its progress and the twelve monthly pictures in the sky.
struct JourneyYearPhotoCard: View {
    struct Month {
        let month: Int
        let litCount: Int
        let numberOfDays: Int
        let isUpcoming: Bool
    }

    let progress: JourneyYearProgress
    let months: [Month]
    var isAnimating = false

    private let monthColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        JourneyCityView(stage: progress.stage, isAnimating: isAnimating)
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
                    Text(verbatim: "\(progress.year)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("\(progress.stage)단계 · \(JourneyCityScene.stageTitles[progress.stage])")
                        .font(.title3.weight(.semibold))
                    ProgressView(value: progress.stageProgress)
                        .tint(.white)
                        .frame(maxWidth: 220)
                        .padding(.top, DiaryTheme.Spacing.small)
                    Text("\(progress.daysWritten)일 기록 · " + (progress.daysToNextStage.map { "다음 단계까지 \($0)일" } ?? "올해의 여정을 모두 완주했어요"))
                        .font(.subheadline)
                        .opacity(0.9)
                    monthStrip
                        .padding(.top, DiaryTheme.Spacing.medium)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 4)
                .padding(24)
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 4) {
                    Text("12개월 보기")
                    Image(systemName: "chevron.right")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.18), in: Capsule())
                .padding(.top, 34)
                .padding(.trailing, 20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            .accessibilityElement(children: .combine)
            .accessibilityHint("그해 12개월 여정을 봅니다")
    }

    /// The year at a glance: each month's picture as far as it was filled.
    private var monthStrip: some View {
        LazyVGrid(columns: monthColumns, spacing: 6) {
            ForEach(months, id: \.month) { month in
                JourneySceneView(scene: JourneySceneCatalog.scene(for: month.month), year: progress.year,
                                 litCount: month.isUpcoming ? 0 : month.litCount, slotCount: month.numberOfDays)
                    .aspectRatio(JourneyScene.canvas.width / JourneyScene.canvas.height, contentMode: .fit)
                    .overlay { if month.isUpcoming { Color.black.opacity(0.5) } }
                    .overlay(alignment: .bottomLeading) {
                        Text("\(month.month)")
                            .font(.caption2.weight(.bold))
                            .padding(4)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.25), lineWidth: 0.5))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Stage, days written and the way to the next stage.
struct JourneyYearProgressSummary: View {
    let progress: JourneyYearProgress

    var body: some View {
        VStack(alignment: .leading, spacing: DiaryTheme.Spacing.small) {
            HStack {
                Text("\(progress.stage)단계 · \(JourneyCityScene.stageTitles[progress.stage])")
                    .font(DiaryTheme.Fonts.section)
                    .foregroundStyle(DiaryTheme.Colors.brand)
                Spacer()
                Text("\(progress.daysWritten)일 기록")
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
            }
            ProgressView(value: progress.stageProgress)
                .tint(DiaryTheme.Colors.brand)
            Text(progress.daysToNextStage.map { "다음 단계까지 \($0)일" } ?? "올해의 여정을 모두 완주했어요")
                .font(DiaryTheme.Fonts.caption)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
        }
    }
}

/// One year: its city on top, then the twelve monthly pictures.
struct JourneyYearView: View {
    let viewModel: JourneyViewModel
    let year: Int
    let onSelectMonth: (JourneyMonth) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DiaryTheme.Spacing.medium), count: 3)

    var body: some View {
        let progress = viewModel.progress(ofYear: year)
        ScrollView {
            VStack(alignment: .leading, spacing: DiaryTheme.Spacing.section) {
                JourneyCityView(stage: progress.stage, isAnimating: true)
                    .aspectRatio(JourneyCityScene.canvas.width / JourneyCityScene.canvas.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
                JourneyYearProgressSummary(progress: progress)
                monthSection
            }
            .padding(DiaryTheme.Spacing.screen)
        }
        .background(DiaryTheme.Colors.background.ignoresSafeArea())
    }

    private var monthSection: some View {
        let completed = (1...12).filter { month in
            let days = viewModel.numberOfDays(year: year, month: month)
            return !viewModel.isUpcoming(year: year, month: month) && days > 0 && viewModel.month(year: year, month: month).days.count >= days
        }.count
        return VStack(alignment: .leading, spacing: DiaryTheme.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("월별 여정")
                    .font(DiaryTheme.Fonts.section)
                    .foregroundStyle(DiaryTheme.Colors.text)
                Spacer()
                Text("완성한 그림 \(completed) / 12")
                    .font(DiaryTheme.Fonts.caption)
                    .foregroundStyle(DiaryTheme.Colors.secondaryText)
            }
            LazyVGrid(columns: columns, spacing: DiaryTheme.Spacing.medium) {
                ForEach(1...12, id: \.self) { month in
                    card(month: month)
                }
            }
        }
    }

    @ViewBuilder
    private func card(month: Int) -> some View {
        let record = viewModel.month(year: year, month: month)
        let days = viewModel.numberOfDays(year: year, month: month)
        let isUpcoming = viewModel.isUpcoming(year: year, month: month)
        let label = JourneyMonthCard(scene: JourneySceneCatalog.scene(for: month), year: year, month: month,
                                     litCount: record.days.count, numberOfDays: days, isUpcoming: isUpcoming)
        if isUpcoming {
            label
        } else {
            Button { onSelectMonth(record) } label: { label }
                .buttonStyle(.plain)
        }
    }
}

private struct JourneyMonthCard: View {
    let scene: JourneyScene
    let year: Int
    let month: Int
    let litCount: Int
    let numberOfDays: Int
    let isUpcoming: Bool

    private var isComplete: Bool { !isUpcoming && numberOfDays > 0 && litCount >= numberOfDays }

    var body: some View {
        JourneySceneView(scene: scene, year: year, litCount: isUpcoming ? 0 : litCount, slotCount: numberOfDays)
            .aspectRatio(JourneyScene.canvas.width / JourneyScene.canvas.height, contentMode: .fit)
            .overlay {
                if isUpcoming {
                    Color.black.opacity(0.55)
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .overlay(alignment: .top) {
                HStack {
                    Text("\(month)월")
                        .font(.headline)
                    Spacer()
                    if isComplete {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.yellow)
                    }
                }
                .foregroundStyle(.white)
                .padding(10)
            }
            .overlay(alignment: .bottom) {
                if !isUpcoming {
                    Text("\(litCount) / \(numberOfDays)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.35), in: Capsule())
                        .padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isUpcoming ? "\(month)월, 아직 열리지 않았어요" : "\(month)월 \(scene.title), \(numberOfDays)일 중 \(litCount)일 채움")
    }
}

/// One month's picture on the whole screen, lighting up to the days written.
struct JourneyMonthDetailView: View {
    let month: JourneyMonth
    let numberOfDays: Int
    let onClose: () -> Void

    private var scene: JourneyScene { JourneySceneCatalog.scene(for: month.month) }

    var body: some View {
        JourneySceneView(scene: scene, year: month.year, litCount: month.days.count, slotCount: numberOfDays, animatesLighting: true)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                VStack(spacing: DiaryTheme.Spacing.small) {
                    Text(verbatim: "\(month.year)년 \(month.month)월")
                        .font(.title.weight(.bold))
                    Text(scene.title)
                        .font(.headline)
                        .opacity(0.85)
                    Text("\(numberOfDays)일 중 \(month.days.count)일을 채웠어요.")
                        .font(.subheadline)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 4)
                .padding(.top, 56)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                }
                .accessibilityLabel("닫기")
                .padding(.trailing, DiaryTheme.Spacing.small)
            }
    }
}
