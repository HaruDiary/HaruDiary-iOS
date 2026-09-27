import UIKit

extension CalendarModule {
    func makeViewController() -> UIViewController {
        CalendarHostingController(viewModel: viewModel, imageLoader: imageLoader)
    }
}
