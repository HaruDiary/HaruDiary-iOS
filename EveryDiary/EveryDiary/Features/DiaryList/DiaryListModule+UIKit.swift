import UIKit

extension DiaryListModule {
    func makeViewController(makeWriteDiary: @escaping MakeWriteDiary,
                            makeSettings: @escaping () -> UIViewController) -> UIViewController {
        DiaryListHostingController(viewModel: viewModel, imageLoader: imageLoader,
                                   makeWriteDiary: makeWriteDiary, makeSettings: makeSettings)
    }
}
