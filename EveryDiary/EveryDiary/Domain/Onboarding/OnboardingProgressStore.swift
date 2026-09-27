import Foundation

@MainActor
protocol OnboardingProgressStore: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
}

@MainActor
final class UserDefaultsOnboardingProgressStore: OnboardingProgressStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasSeenOnboarding") }
        set { defaults.set(newValue, forKey: "hasSeenOnboarding") }
    }
}
