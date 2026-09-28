import UIKit

extension DiaryListModule {
    func makeViewController(makeSettings: @escaping () -> UIViewController) -> UIViewController {
        DiaryListHostingController(viewModel: viewModel, imageLoader: imageLoader, makeSettings: makeSettings)
    }
}
