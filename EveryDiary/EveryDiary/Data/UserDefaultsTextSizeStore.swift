import Foundation

struct UserDefaultsTextSizeStore: AppTextSizeStoring {
    static let key = "appTextSize"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// An unknown stored value (from a later version) follows the phone.
    var textSize: AppTextSize {
        get { defaults.string(forKey: Self.key).flatMap(AppTextSize.init(rawValue:)) ?? .system }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.key) }
    }
}
