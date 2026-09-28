import UIKit

extension CalendarModule {
    func makeViewController(makeSettings: @escaping () -> UIViewController) -> UIViewController {
        CalendarHostingController(viewModel: viewModel, imageLoader: imageLoader, makeSettings: makeSettings)
    }
}
