import SwiftUI

struct OnboardingView: View {
    let viewModel: OnboardingViewModel
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPageSettling = false

    var body: some View {
        VStack(spacing: 0) {
            header
            pager
            footer
        }
        .frame(maxWidth: DiaryTheme.Onboarding.contentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DiaryTheme.Colors.onboardingBackground.ignoresSafeArea())
        .foregroundStyle(DiaryTheme.Colors.brand)
        .onChange(of: viewModel.isCompleted) { _, completed in
            if completed { onComplete() }
        }
    }

    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: DiaryTheme.Onboarding.pageDuration)))
    private var dragOffset: CGFloat = 0

    private var pager: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // Keep page identities stable and animate the strip itself. TabView's selection
            // update can replace the visible page without animating a programmatic change.
            HStack(spacing: 0) {
                ForEach(OnboardingPage.allCases) { page in
                    OnboardingPageView(page: page)
                        .frame(width: width, height: geometry.size.height)
                        .accessibilityHidden(page != viewModel.selectedPage)
                        .allowsHitTesting(page == viewModel.selectedPage && !isPageSettling)
                }
            }
            .frame(width: width * CGFloat(OnboardingPage.allCases.count), alignment: .leading)
            .offset(x: -CGFloat(viewModel.selectedPage.rawValue) * width + dragOffset)
            .frame(width: width, height: geometry.size.height, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 15)
                    .updating($dragOffset) { value, offset, transaction in
                        guard !isPageSettling, !viewModel.isCompleted,
                              abs(value.translation.width) > abs(value.translation.height) else { return }
                        transaction.animation = nil
                        let translation = value.translation.width
                        let beyondStart = viewModel.selectedPage == .record && translation > 0
                        let beyondEnd = viewModel.isLastPage && translation < 0
                        offset = beyondStart || beyondEnd ? translation / 3 : translation
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        let distance = value.predictedEndTranslation.width
                        guard abs(distance) > width * 0.18 else { return }
                        movePage(by: distance < 0 ? 1 : -1)
                    }
            )
            .accessibilityScrollAction { edge in
                if edge == .trailing { movePage(by: 1) }
                if edge == .leading { movePage(by: -1) }
            }
            .transaction { if reduceMotion { $0.animation = nil } }
        }
        .accessibilityIdentifier("onboarding.pages")
    }

    private func movePage(by offset: Int) {
        guard let page = OnboardingPage(rawValue: viewModel.selectedPage.rawValue + offset) else { return }
        changePage { viewModel.select(page) }
    }

    private var header: some View {
        HStack(spacing: DiaryTheme.Spacing.small) {
            Text("하루일기")
                .font(DiaryTheme.Fonts.section)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DiaryTheme.Spacing.small)
            Button("건너뛰기") { viewModel.skip() }
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.Colors.secondaryText)
                .frame(minHeight: DiaryTheme.Size.touchTarget)
                .accessibilityHint("소개를 마치고 일기 목록으로 이동합니다")
                .accessibilityIdentifier("onboarding.skip")
                .disabled(viewModel.isCompleted)
        }
        .padding(.horizontal, DiaryTheme.Spacing.section)
        .padding(.top, DiaryTheme.Spacing.small)
    }

    private var footer: some View {
        VStack(spacing: DiaryTheme.Spacing.medium) {
            HStack(spacing: 0) {
                ForEach(OnboardingPage.allCases) { page in
                    Button {
                        changePage { viewModel.select(page) }
                    } label: {
                        Circle()
                            .fill(viewModel.selectedPage == page
                                  ? DiaryTheme.Colors.brand
                                  : DiaryTheme.Colors.brand.opacity(0.16))
                            .frame(width: 7, height: 7)
                            .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isPageSettling || viewModel.isCompleted)
                    .accessibilityLabel("\(page.rawValue + 1)/\(OnboardingPage.allCases.count)페이지, \(page.chapter)")
                    .accessibilityAddTraits(viewModel.selectedPage == page ? .isSelected : [])
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.selectedPage)

            Button {
                changePage { viewModel.advance() }
            } label: {
                HStack {
                    Spacer(minLength: 0)
                    Text(viewModel.isLastPage ? "시작하기" : "다음")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DiaryTheme.Spacing.section)
                .padding(.vertical, DiaryTheme.Spacing.screen)
                .frame(minHeight: DiaryTheme.Onboarding.buttonHeight)
                .frame(maxWidth: .infinity)
                .foregroundStyle(DiaryTheme.Colors.surface)
                .background(DiaryTheme.Colors.brand, in: RoundedRectangle(cornerRadius: DiaryTheme.Radius.card))
            }
            .buttonStyle(OnboardingPressStyle())
            .disabled(isPageSettling || viewModel.isCompleted)
            .accessibilityIdentifier("onboarding.next")
        }
        .padding(.horizontal, DiaryTheme.Spacing.section)
        .padding(.bottom, DiaryTheme.Spacing.screen)
    }

    private func changePage(_ action: () -> Void) {
        guard !isPageSettling, !viewModel.isCompleted else { return }
        let previousPage = viewModel.selectedPage
        isPageSettling = true
        withAnimation(reduceMotion ? nil : .easeInOut(duration: DiaryTheme.Onboarding.pageDuration),
                      completionCriteria: .logicallyComplete) {
            action()
        } completion: {
            isPageSettling = false
        }
        if viewModel.selectedPage == previousPage { isPageSettling = false }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DiaryTheme.Spacing.section) {
                    Image(page.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: illustrationHeight(in: geometry.size))
                        .accessibilityHidden(true)

                    VStack(spacing: DiaryTheme.Spacing.medium) {
                        Text(page.title)
                            .font(DiaryTheme.Onboarding.title)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(page.subtitle)
                            .font(DiaryTheme.Fonts.body)
                            .foregroundStyle(DiaryTheme.Colors.secondaryText)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)

                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, DiaryTheme.Spacing.section)
                .padding(.vertical, DiaryTheme.Spacing.screen)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private func illustrationHeight(in size: CGSize) -> CGFloat {
        let available = dynamicTypeSize.isAccessibilitySize ? size.height * 0.32 : size.height * 0.48
        return min(size.width - DiaryTheme.Spacing.section * 2,
                   max(DiaryTheme.Onboarding.illustrationMinHeight,
                       min(DiaryTheme.Onboarding.illustrationMaxHeight, available)))
    }
}

private struct OnboardingPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: DiaryTheme.Onboarding.pressDuration), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview("기록하기") {
    OnboardingPreview(page: .record)
}

#Preview("불빛") {
    OnboardingPreview(page: .light)
}

#Preview("여정") {
    OnboardingPreview(page: .journey)
}

#Preview("캘린더") {
    OnboardingPreview(page: .revisit)
}

#Preview("간직하기 · 큰 글자") {
    OnboardingPreview(page: .keep)
        .environment(\.dynamicTypeSize, .accessibility3)
}

private struct OnboardingPreview: View {
    @State private var viewModel: OnboardingViewModel

    init(page: OnboardingPage) {
        let model = OnboardingViewModel(store: PreviewProgressStore())
        model.select(page)
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        OnboardingView(viewModel: viewModel, onComplete: {})
    }
}

@MainActor
private final class PreviewProgressStore: OnboardingProgressStore {
    var hasCompletedOnboarding = false
}
#endif
