import UIKit

extension JourneyModule {
    func makeViewController(makeWriteDiary: @escaping MakeWriteDiary,
                            makeSettings: @escaping () -> UIViewController) -> UIViewController {
        MotivationVC(viewModel: viewModel, makeWriteDiary: makeWriteDiary, makeSettings: makeSettings)
    }
}
