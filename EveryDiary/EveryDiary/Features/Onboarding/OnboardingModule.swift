import SwiftUI
import UIKit

@MainActor
enum OnboardingModule {
    // This small bridge disappears when the app's UIKit root becomes a SwiftUI app shell.
    // The main factory is lazy so the first launch cannot flash the diary list underneath onboarding.
    static func install(
        in window: UIWindow,
        store: (any OnboardingProgressStore)? = nil,
        makeMainController: @escaping @MainActor () -> UIViewController
    ) {
        let store = store ?? UserDefaultsOnboardingProgressStore()
        guard !store.hasCompletedOnboarding else {
            window.rootViewController = makeMainController()
            return
        }
        let model = OnboardingViewModel(store: store)
        let controller = UIHostingController(rootView: OnboardingView(viewModel: model) { [weak window] in
            guard let window else { return }
            let main = makeMainController()
            if UIAccessibility.isReduceMotionEnabled {
                window.rootViewController = main
            } else {
                UIView.transition(with: window, duration: DiaryTheme.Onboarding.pageDuration,
                                  options: [.transitionCrossDissolve, .allowAnimatedContent]) {
                    window.rootViewController = main
                }
            }
        })
        controller.view.backgroundColor = UIColor(named: "onboardingBackground")
        window.rootViewController = controller
    }
}
