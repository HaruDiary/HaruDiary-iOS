import Observation
import UIKit

/// Applies the app's text size to its windows. Every screen in a window (UIKit and SwiftUI, sheets included)
/// reads its text size from the window, so one override covers the whole app.
@MainActor
@Observable
final class AppTextSizeController {
    private(set) var setting: AppTextSize

    @ObservationIgnored private let store: any AppTextSizeStoring
    @ObservationIgnored private var windows: [() -> UIWindow?] = []
    @ObservationIgnored private var systemObserver: NSObjectProtocol?

    init(store: any AppTextSizeStoring) {
        self.store = store
        setting = store.textSize
        // The phone's own size changed: the larger of the two is used again.
        systemObserver = NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyToWindows() }
        }
    }

    deinit {
        if let systemObserver { NotificationCenter.default.removeObserver(systemObserver) }
    }

    func select(_ setting: AppTextSize) {
        guard setting != self.setting else { return }
        self.setting = setting
        store.textSize = setting
        applyToWindows()
    }

    /// The window follows the setting and the phone's text size from now on, also a window created later
    /// such as the lock screen's. The window is not kept alive by this.
    func attach(to window: UIWindow) {
        windows.removeAll { $0() == nil }
        windows.append { [weak window] in window }
        apply(to: window)
    }

    private func apply(to window: UIWindow) {
        let system = Self.steps.firstIndex(of: UIApplication.shared.preferredContentSizeCategory) ?? AppTextSize.defaultStep
        if let step = setting.step(systemStep: system) {
            window.traitOverrides.preferredContentSizeCategory = Self.steps[step]
        } else {
            window.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
        }
    }

    private func applyToWindows() {
        windows.removeAll { $0() == nil }
        windows.compactMap { $0() }.forEach(apply(to:))
    }

    /// The system's text sizes in order, matching `AppTextSize` steps.
    static let steps: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
        .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
        .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge,
    ]
}
