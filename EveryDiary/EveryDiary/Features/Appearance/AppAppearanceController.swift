import Observation
import UIKit

/// Applies the app's light or dark choice to its windows. Everything shown in a window, sheets included,
/// takes its appearance from the window, so one override covers the whole app.
@MainActor
@Observable
final class AppAppearanceController {
    private(set) var setting: AppAppearance

    @ObservationIgnored private let store: any AppAppearanceStoring
    @ObservationIgnored private var windows: [() -> UIWindow?] = []

    init(store: any AppAppearanceStoring) {
        self.store = store
        setting = store.appearance
    }

    func select(_ setting: AppAppearance) {
        guard setting != self.setting else { return }
        self.setting = setting
        store.appearance = setting
        windows.removeAll { $0() == nil }
        windows.compactMap { $0() }.forEach(apply(to:))
    }

    /// The window follows the setting from now on, also a window created later such as the lock screen's.
    /// The window is not kept alive by this.
    func attach(to window: UIWindow) {
        windows.removeAll { $0() == nil }
        windows.append { [weak window] in window }
        apply(to: window)
    }

    private func apply(to window: UIWindow) {
        window.overrideUserInterfaceStyle = Self.style(for: setting)
    }

    static func style(for setting: AppAppearance) -> UIUserInterfaceStyle {
        switch setting {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}
