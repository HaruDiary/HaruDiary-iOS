import UIKit

extension CalendarModule {
    func makeViewController(makeWriteDiary: @escaping MakeWriteDiary,
                            makeSettings: @escaping () -> UIViewController) -> UIViewController {
        CalendarHostingController(viewModel: viewModel, imageLoader: imageLoader,
                                  makeWriteDiary: makeWriteDiary, makeSettings: makeSettings)
    }
}
