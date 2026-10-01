import Foundation

struct UserDefaultsAppearanceStore: AppAppearanceStoring {
    static let key = "appAppearance"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// An unknown stored value (from a later version) follows the phone.
    var appearance: AppAppearance {
        get { defaults.string(forKey: Self.key).flatMap(AppAppearance.init(rawValue:)) ?? .system }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.key) }
    }
}
