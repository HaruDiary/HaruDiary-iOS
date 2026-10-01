import SwiftUI

/// The journey tab: this month's picture, which gains one light for each day a diary was written.
struct JourneyView: View {
    let viewModel: JourneyViewModel
    let onWriteDiary: () -> Void
    let onOpenCollection: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    /// Read again when the app returns or the day changes, so the month moves on while the app stays open.
    @State private var refresh = 0
    @ScaledMetric(relativeTo: .title) private var monthSize: CGFloat = 25
    @ScaledMetric(relativeTo: .body) private var countSize: CGFloat = 16
    @ScaledMetric(relativeTo: .footnote) private var sceneSize: CGFloat = 14

    var body: some View {
        let _ = refresh
        let month = viewModel.currentMonth
        let scene = JourneySceneCatalog.scene(for: month.month)
        let failed = viewModel.state == .failed
        ZStack(alignment: .bottomTrailing) {
            // The picture fills the whole screen; the floating tab bar sits over its ground.
            JourneySceneView(scene: scene, year: month.year, litCount: month.days.count,
                             slotCount: viewModel.numberOfDaysInCurrentMonth, animatesLighting: true)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                // The same title and buttons as the other tabs, in white over the picture.
                DiaryTabHeader(title: "여정", tint: .white,
                               extra: .init(systemImage: "square.grid.2x2", label: "나의 여정", action: onOpenCollection),
                               onOpenSettings: onOpenSettings)
                Text("\(month.month)월")
                    .font(.system(size: monthSize, weight: .bold))
                    .padding(.top, 20)
                    .accessibilityAddTraits(.isHeader)
                Text(failed ? "여정을 불러오지 못했어요." : "\(viewModel.numberOfDaysInCurrentMonth)일 중 \(month.days.count)개 작성했어요.")
                    .font(.system(size: countSize))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                Text(scene.title)
                    .font(.system(size: sceneSize, weight: .semibold))
                    .opacity(0.85)
                    .padding(.top, 6)
                if failed {
                    // The journey can be loaded again once the network is back.
                    Button { viewModel.retry() } label: {
                        Label("다시 불러오기", systemImage: "arrow.clockwise")
                            .padding(.horizontal, DiaryTheme.Spacing.screen)
                            .frame(minHeight: DiaryTheme.Size.touchTarget)
                            .background(.white.opacity(0.25), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 3)
            .padding(DiaryTheme.Spacing.screen)
            DiaryWriteButton(image: "writeLight", action: onWriteDiary)
        }
        .onAppear {
            refresh += 1
            if viewModel.state == .failed { viewModel.retry() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh += 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { @MainActor in refresh += 1 }
        }
    }
}

/// One year's months; picking a month shows its picture on the whole screen.
struct JourneyYearScreen: View {
    let viewModel: JourneyViewModel
    let year: Int
    @State private var shownMonth: JourneyMonthSelection?

    var body: some View {
        JourneyYearView(viewModel: viewModel, year: year, onSelectMonth: { shownMonth = JourneyMonthSelection(month: $0) })
            .navigationTitle(Text(verbatim: "\(year)년"))
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $shownMonth) { selection in
                JourneyMonthDetailView(month: selection.month,
                                       numberOfDays: viewModel.numberOfDays(year: selection.month.year, month: selection.month.month),
                                       onClose: { shownMonth = nil })
            }
    }
}

struct JourneyMonthSelection: Identifiable {
    let month: JourneyMonth
    var id: String { "\(month.year)-\(month.month)" }
}
