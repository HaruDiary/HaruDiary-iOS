import Foundation

/// A mood or weather a diary can carry. `value` is what diaries store (an asset name), so it must never change.
struct DiaryCondition: Equatable, Identifiable {
    let value: String
    let label: String
    var id: String { value }
}

/// The choices of the previous condition picker, in its order, with the names of the redesign (mockups 07 and 08).
enum DiaryConditions {
    static let emotions: [DiaryCondition] = [
        DiaryCondition(value: "Smiling face with smiling eyes", label: "좋음"),
        DiaryCondition(value: "Grinning face", label: "신남"),
        DiaryCondition(value: "Neutral face", label: "보통"),
        DiaryCondition(value: "Disappointed but relieved face", label: "아쉬움"),
        DiaryCondition(value: "Persevering face", label: "힘듦"),
        DiaryCondition(value: "Loudly crying face", label: "슬픔"),
        DiaryCondition(value: "Pouting face", label: "화남"),
        DiaryCondition(value: "Sleeping face", label: "졸림"),
        DiaryCondition(value: "Face screaming in fear", label: "놀람"),
        DiaryCondition(value: "Face vomiting", label: "메스꺼움"),
        DiaryCondition(value: "Face with medical mask", label: "아픔"),
    ]

    static let weathers: [DiaryCondition] = [
        DiaryCondition(value: "u_sun", label: "맑음"),
        DiaryCondition(value: "u_cloud-sun", label: "구름 조금"),
        DiaryCondition(value: "u_clouds", label: "흐림"),
        DiaryCondition(value: "fi_wind", label: "바람"),
        DiaryCondition(value: "u_cloud-showers-heavy", label: "비"),
        DiaryCondition(value: "u_moon", label: "맑은 밤"),
        DiaryCondition(value: "u_cloud-moon", label: "흐린 밤"),
        DiaryCondition(value: "u_rainbow", label: "무지개"),
        DiaryCondition(value: "u_snowflake", label: "눈"),
        DiaryCondition(value: "u_thunderstorm", label: "번개"),
    ]

    /// Empty for no choice; an unknown stored value keeps showing its image without a name.
    static func emotionLabel(_ value: String) -> String? {
        emotions.first { $0.value == value }?.label
    }

    static func weatherLabel(_ value: String) -> String? {
        weathers.first { $0.value == value }?.label
    }
}
