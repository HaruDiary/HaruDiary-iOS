import UIKit

extension TrashModule {
    func makeViewController(makeWriteDiary: @escaping MakeWriteDiary) -> UIViewController {
        TrashHostingController(viewModel: viewModel, imageLoader: imageLoader, makeWriteDiary: makeWriteDiary)
    }
}
