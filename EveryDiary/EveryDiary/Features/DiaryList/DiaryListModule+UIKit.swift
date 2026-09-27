import UIKit

extension DiaryListModule {
    func makeViewController() -> UIViewController {
        DiaryListHostingController(viewModel: viewModel, imageLoader: imageLoader)
    }
}
