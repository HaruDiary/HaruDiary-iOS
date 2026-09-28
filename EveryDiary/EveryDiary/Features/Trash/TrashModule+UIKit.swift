import UIKit

extension TrashModule {
    func makeViewController() -> UIViewController {
        TrashHostingController(viewModel: viewModel, imageLoader: imageLoader)
    }
}
