import Foundation

/// The app's own text size, for people who want large text here without changing the whole phone.
/// The phone's setting still counts: the app never shows text smaller than the phone asks for.
enum AppTextSize: String, CaseIterable, Identifiable {
    /// Follows the phone's text size.
    case system
    case large
    case extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "기본"
        case .large: return "크게"
        case .extraLarge: return "아주 크게"
        }
    }

    var detail: String {
        switch self {
        case .system: return "iPhone의 글자 크기 설정을 따라요"
        case .large: return "글자를 크게 보여줘요"
        case .extraLarge: return "글자를 가장 크게 보여줘요"
        }
    }

    /// Steps count the system's twelve text sizes from the smallest (0); the default is 3.
    static let stepCount = 12
    static let defaultStep = 3

    /// The step this setting asks for at least; nil follows the phone.
    var minimumStep: Int? {
        switch self {
        case .system: return nil
        case .large: return 6        // the largest standard size (body 23pt)
        case .extraLarge: return 8   // the second accessibility size (body 33pt)
        }
    }

    /// The step to show for a phone set to `systemStep`; nil means no override is needed.
    func step(systemStep: Int) -> Int? {
        guard let minimumStep, minimumStep > systemStep else { return nil }
        return min(minimumStep, Self.stepCount - 1)
    }
}

protocol AppTextSizeStoring {
    var textSize: AppTextSize { get nonmutating set }
}
