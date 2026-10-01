import Foundation
import Observation

/// What the first launch tells about, in the order of the pages.
enum OnboardingPage: Int, CaseIterable, Identifiable {
    case record, calendar, memories, journey, keep

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .record: "오늘 하루를 글과 사진으로 남겨요"
        case .calendar: "기분이 달력에 남아요"
        case .memories: "지난 하루를 다시 만나요"
        case .journey: "쓴 날만큼 그림이 채워져요"
        case .keep: "소중한 기록을 안전하게"
        }
    }

    var subtitle: String {
        switch self {
        case .record: "기분과 날씨, 사진 세 장까지 함께 담아요.\n쓰다 만 글은 다음에 이어서 쓸 수 있어요."
        case .calendar: "날짜마다 그날의 기분이 보이고,\n한 달의 기분을 한눈에 모아 봐요."
        case .memories: "작년 오늘 쓴 일기를 보여 드리고,\n제목과 내용으로 찾아볼 수 있어요."
        case .journey: "달마다 그림에 불이 하나씩 켜지고,\n한 해의 기록으로 도시가 자라요."
        case .keep: "로그인하면 기기를 바꿔도 일기가 남아요.\n앱 잠금과 파일 내보내기도 있어요."
        }
    }

    var chapter: String {
        switch self {
        case .record: "기록"
        case .calendar: "캘린더"
        case .memories: "다시 보기"
        case .journey: "여정"
        case .keep: "보관"
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
