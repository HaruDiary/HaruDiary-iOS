//
//  MotivationVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import UIKit

import Observation
import SwiftUI

class MotivationVC: UIViewController {
    // This month's picture; each diary day turns on one more light.
    private lazy var scene = UIHostingController(rootView: makeSceneView())
    private let viewModel: JourneyViewModel
    private let makeWriteDiary: MakeWriteDiary
    private let makeSettings: () -> UIViewController
    
    init(viewModel: JourneyViewModel, makeWriteDiary: @escaping MakeWriteDiary,
         makeSettings: @escaping () -> UIViewController) {
        self.viewModel = viewModel
        self.makeWriteDiary = makeWriteDiary
        self.makeSettings = makeSettings
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { return nil }
    
    // The same title and buttons as the other tabs, in white over the picture.
    private lazy var header: UIHostingController<DiaryTabHeader> = {
        let header = UIHostingController(rootView: DiaryTabHeader(
            title: "여정", tint: .white,
            extra: .init(systemImage: "square.grid.2x2", label: "나의 여정") { [weak self] in self?.honorVCBTN() },
            onOpenSettings: { [weak self] in self?.tabSettingBTN() }
        ))
        header.view.backgroundColor = .clear
        header.safeAreaRegions = []
        return header
    }()
    
    private lazy var writeDiaryButton : UIButton = {
        var config = UIButton.Configuration.plain()
        let button = UIButton(configuration: config)
        button.setImage(UIImage(named: "writeLight"), for: .normal)
        button.addTarget(self, action: #selector(tabWriteDiaryBTN), for: .touchUpInside)
        return button
    }()
    
    private lazy var monthLabel: UILabel = {
        let monthLabel = UILabel()
        monthLabel.font = .systemFont(ofSize: 25, weight: .bold)
        monthLabel.textColor = .white
        return monthLabel
    }()
    
    private lazy var countLabel: UILabel = {
        let countLabel = UILabel()
        countLabel.font = .systemFont(ofSize: 16)
        countLabel.textColor = .white
        return countLabel
    }()
    
    // Shown when the diary subscription fails, so the journey can be loaded again once the network is back.
    private lazy var retryButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "다시 불러오기"
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.25)
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(tapRetry), for: .touchUpInside)
        button.isHidden = true
        return button
    }()
    
    private lazy var sceneLabel: UILabel = {
        let sceneLabel = UILabel()
        sceneLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        sceneLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        return sceneLabel
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNavigationBar()
        // The month is read again here, so it moves on while the app stays open.
        render()
        if viewModel.state == .failed { viewModel.retry() }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSubview()
        autoLayout()
        observeViewModel()
        viewModel.start()
    }
    
    // The tab lives as long as the signed-in app, so the subscription stays until the view model is released.
    private func observeViewModel() {
        withObservationTracking {
            _ = viewModel.record
            _ = viewModel.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.render()
                self?.observeViewModel()
            }
        }
        render()
    }
    
    private func render() {
        let month = viewModel.currentMonth
        monthLabel.text = "\(month.month)월"
        let failed = viewModel.state == .failed
        countLabel.text = failed ? "여정을 불러오지 못했어요." : "\(viewModel.numberOfDaysInCurrentMonth)일 중 \(month.days.count)개 작성했어요."
        retryButton.isHidden = !failed
        sceneLabel.text = JourneySceneCatalog.scene(for: month.month).title
        scene.rootView = makeSceneView()
    }
    
    private func makeSceneView() -> JourneySceneView {
        let month = viewModel.currentMonth
        return JourneySceneView(scene: JourneySceneCatalog.scene(for: month.month), year: month.year, litCount: month.days.count,
                                slotCount: viewModel.numberOfDaysInCurrentMonth, animatesLighting: true)
    }
    
    @objc private func tabSettingBTN() {
        let settingVC = makeSettings()
        settingVC.hidesBottomBarWhenPushed = true
        showNavigationBarForPush()
        navigationController?.pushViewController(settingVC, animated: true)
    }
    
    @objc private func tabWriteDiaryBTN() {
        let writeDiaryVC = makeWriteDiary()
        writeDiaryVC.enterDiary(to: .writeNewDiary)
        writeDiaryVC.delegate = self
        writeDiaryVC.modalPresentationStyle = .automatic
        self.present(writeDiaryVC, animated: true)
    }
    
    @objc private func tapRetry() {
        viewModel.retry()
    }
    
    @objc private func honorVCBTN() {
        let honorVC = JourneyCollectionHostingController(viewModel: viewModel)
        honorVC.hidesBottomBarWhenPushed = true
        showNavigationBarForPush()
        navigationController?.pushViewController(honorVC, animated: true)
    }

    private func showNavigationBarForPush() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.tintColor = DiaryTheme.Colors.brandUIKit
    }
    
    func addSubview() {
        addChild(scene)
        view.addSubview(scene.view)
        scene.didMove(toParent: self)
        scene.view.backgroundColor = .clear
        // The sky fills the screen behind the navigation bar, as the old background image did.
        scene.safeAreaRegions = []
        addChild(header)
        view.addSubview(header.view)
        header.didMove(toParent: self)
        view.addSubview(writeDiaryButton)
        view.addSubview(monthLabel)
        view.addSubview(countLabel)
        view.addSubview(sceneLabel)
        view.addSubview(retryButton)
        [monthLabel, countLabel, sceneLabel].forEach {
            $0.layer.shadowColor = UIColor.black.cgColor
            $0.layer.shadowOpacity = 0.3
            $0.layer.shadowRadius = 3
            $0.layer.shadowOffset = .zero
        }
    }
    
    func autoLayout() {
        let views: [UIView] = [scene.view, writeDiaryButton, header.view, monthLabel, countLabel, sceneLabel, retryButton]
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // The picture fills the whole screen; the floating tab bar sits over its ground.
            scene.view.topAnchor.constraint(equalTo: view.topAnchor),
            scene.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scene.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scene.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            writeDiaryButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -10),
            writeDiaryButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -32),

            // The same place as the list and calendar headers: the screen padding on every side.
            header.view.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 16),
            header.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            monthLabel.topAnchor.constraint(equalTo: header.view.bottomAnchor, constant: 20),
            monthLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countLabel.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 16),
            countLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sceneLabel.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 6),
            sceneLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: sceneLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // The tab draws its own header; pushed screens show the navigation bar again.
    private func setNavigationBar() {
        navigationController?.setNavigationBarHidden(true, animated: true)
        navigationItem.backButtonTitle = "여정"
    }
}

extension MotivationVC : DiaryUpdateDelegate {
    func diaryDidUpdate() {
        // The live subscription already reflects the saved diary; only a failed one needs a new start.
        if viewModel.state == .failed { viewModel.retry() }
    }
}
