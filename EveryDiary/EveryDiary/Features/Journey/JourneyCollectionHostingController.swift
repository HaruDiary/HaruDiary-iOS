import SwiftUI
import UIKit

// UIKit bridge while the journey tab shell is still UIKit; remove when the tab migrates to SwiftUI.
/// Years (each a growing city) → one year's city and months → one month's picture.
@MainActor
final class JourneyCollectionHostingController: UIHostingController<JourneyYearsView> {
    private let viewModel: JourneyViewModel

    init(viewModel: JourneyViewModel) {
        self.viewModel = viewModel
        super.init(rootView: JourneyYearsView(viewModel: viewModel, onSelectYear: { _ in }))
        rootView = JourneyYearsView(viewModel: viewModel, onSelectYear: { [weak self] in self?.openYear($0) })
        title = "나의 여정"
    }

    required init?(coder: NSCoder) { return nil }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.tintColor = DiaryTheme.Colors.brandUIKit
    }

    private func openYear(_ year: Int) {
        let yearController = UIHostingController(rootView: JourneyYearView(viewModel: viewModel, year: year, onSelectMonth: { _ in }))
        yearController.rootView = JourneyYearView(viewModel: viewModel, year: year, onSelectMonth: { [weak self, weak yearController] month in
            guard let self, let yearController else { return }
            self.presentMonth(month, from: yearController)
        })
        yearController.title = "\(year)년"
        navigationController?.pushViewController(yearController, animated: true)
    }

    private func presentMonth(_ month: JourneyMonth, from presenter: UIViewController) {
        let numberOfDays = viewModel.numberOfDays(year: month.year, month: month.month)
        let detail = UIHostingController(rootView: JourneyMonthDetailView(month: month, numberOfDays: numberOfDays, onClose: {}))
        detail.rootView = JourneyMonthDetailView(month: month, numberOfDays: numberOfDays,
                                                 onClose: { [weak detail] in detail?.dismiss(animated: true) })
        detail.modalPresentationStyle = .fullScreen
        presenter.present(detail, animated: true)
    }
}
