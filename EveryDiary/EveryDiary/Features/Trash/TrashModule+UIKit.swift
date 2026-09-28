import UIKit

extension TrashModule {
    func makeViewController() -> UIViewController {
        TrashHostingController(viewModel: viewModel, imageLoader: imageLoader)
    }

    // SettingVC is still created without dependencies from several UIKit screens.
    // Remove this once settings migrates and receives AppDependencies like the tab features.
    static func makeLiveViewController() -> UIViewController {
        AppDependencies.live().makeTrashModule().makeViewController()
    }
}
