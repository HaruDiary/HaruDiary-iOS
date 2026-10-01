import Foundation

/// Light or dark, for people who want the app one way whatever the phone is set to.
enum AppAppearance: String, CaseIterable, Identifiable {
    /// Follows the phone.
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "시스템 설정"
        case .light: return "라이트"
        case .dark: return "다크"
        }
    }

    var detail: String {
        switch self {
        case .system: return "iPhone의 화면 모드를 따라요"
        case .light: return "항상 밝은 화면으로 보여줘요"
        case .dark: return "항상 어두운 화면으로 보여줘요"
        }
    }
}

protocol AppAppearanceStoring {
    var appearance: AppAppearance { get nonmutating set }
}
