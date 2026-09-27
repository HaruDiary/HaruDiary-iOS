import Foundation
import Observation

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case record, light, journey, revisit, keep

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .record: "오늘의 일기를 기록해보아요"
        case .light: "일기를 작성하고 불을 밝히세요"
        case .journey: "일기를 채우고 건물을 세우세요"
        case .revisit: "캘린더로 기록한 일기를 확인해요"
        case .keep: "일기를 안전하게 저장하세요"
        }
    }

    var subtitle: String {
        switch self {
        case .record: "글과 사진으로 하루를 남겨요"
        case .light: "기록한 하루가 작은 불빛이 돼요"
        case .journey: "한 달의 기록이 나만의 풍경으로"
        case .revisit: "다시 보고 싶은 날을 찾아보세요"
        case .keep: "소중한 이야기를 오래 간직하세요"
        }
    }

    var chapter: String {
        switch self {
        case .record: "기록"
        case .light: "불빛"
        case .journey: "여정"
        case .revisit: "캘린더"
        case .keep: "보관"
        }
    }

    var imageName: String {
        switch self {
        case .record: "onboarding-mockup-record"
        case .light: "onboarding-mockup-light"
        case .journey: "onboarding-mockup-journey"
        case .revisit: "onboarding-mockup-revisit"
        case .keep: "onboarding-mockup-keep"
        }
    }
}

@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var selectedPage: OnboardingPage = .record
    private(set) var isCompleted: Bool
    @ObservationIgnored private let store: any OnboardingProgressStore

    init(store: any OnboardingProgressStore) {
        self.store = store
        isCompleted = store.hasCompletedOnboarding
    }

    var isLastPage: Bool { selectedPage == .keep }

    func select(_ page: OnboardingPage) {
        guard !isCompleted else { return }
        selectedPage = page
    }

    func advance() {
        guard !isCompleted else { return }
        if let next = OnboardingPage(rawValue: selectedPage.rawValue + 1) {
            selectedPage = next
        } else {
            complete()
        }
    }

    func skip() {
        complete()
    }

    private func complete() {
        guard !isCompleted else { return }
        // Onboarding only records progress. It never changes the signed-in account.
        store.hasCompletedOnboarding = true
        isCompleted = true
    }
}
