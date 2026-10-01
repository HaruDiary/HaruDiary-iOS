import SwiftUI

/// The app's root: onboarding on the first launch, then the tabs.
struct AppRootView: View {
    let shell: AppShell
    let dependencies: AppDependencies
    /// Nil once onboarding is done. The tabs are not built under it, so the first launch starts no diary subscription
    /// and cannot flash the diary list.
    @State private var onboarding: OnboardingViewModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @MainActor
    init(shell: AppShell, dependencies: AppDependencies, store: (any OnboardingProgressStore)? = nil) {
        let store = store ?? UserDefaultsOnboardingProgressStore()
        self.shell = shell
        self.dependencies = dependencies
        _onboarding = State(initialValue: store.hasCompletedOnboarding ? nil : OnboardingViewModel(store: store))
    }

    var body: some View {
        ZStack {
            if let onboarding {
                OnboardingView(viewModel: onboarding) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: DiaryTheme.Onboarding.pageDuration)) {
                        self.onboarding = nil
                    }
                }
                .transition(.opacity)
                // The illustrations are drawn on a light background, so onboarding stays light.
                .preferredColorScheme(.light)
            } else {
                MainTabsView(shell: shell, dependencies: dependencies)
                    .transition(.opacity)
            }
        }
    }
}
