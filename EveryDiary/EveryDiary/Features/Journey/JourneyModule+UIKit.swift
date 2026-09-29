import UIKit

extension JourneyModule {
    func makeViewController(makeSettings: @escaping () -> UIViewController) -> UIViewController {
        MotivationVC(viewModel: viewModel, makeSettings: makeSettings)
    }
}
