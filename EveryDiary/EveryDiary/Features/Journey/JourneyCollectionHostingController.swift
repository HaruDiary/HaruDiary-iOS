import SwiftUI
import UIKit

// UIKit bridge while the journey tab shell is still UIKit; remove when the tab migrates to SwiftUI.
@MainActor
final class JourneyCollectionHostingController: UIHostingController<JourneyCollectionView> {
    private let viewModel: JourneyViewModel

    init(viewModel: JourneyViewModel) {
        self.viewModel = viewModel
        super.init(rootView: JourneyCollectionView(viewModel: viewModel, onSelect: { _ in }))
        rootView = JourneyCollectionView(viewModel: viewModel, onSelect: { [weak self] in self?.openDetail(for: $0) })
        title = "나의 여정"
    }

    required init?(coder: NSCoder) { return nil }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.tintColor = DiaryTheme.Colors.brandUIKit
    }

    private func openDetail(for month: JourneyMonth) {
        let detail = UIHostingController(rootView: JourneyMonthDetailView(
            month: month, numberOfDays: viewModel.numberOfDays(year: month.year, month: month.month), onClose: {}
        ))
        detail.rootView = JourneyMonthDetailView(
            month: month, numberOfDays: viewModel.numberOfDays(year: month.year, month: month.month),
            onClose: { [weak detail] in detail?.dismiss(animated: true) }
        )
        detail.modalPresentationStyle = .fullScreen
        present(detail, animated: true)
    }
}
