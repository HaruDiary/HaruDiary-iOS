//
//  MotivationVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import UIKit

import Observation
import SnapKit
import SwiftUI

class MotivationVC: UIViewController {
    // This month's picture; each diary day turns on one more light.
    private lazy var scene = UIHostingController(rootView: makeSceneView())
    private let viewModel: JourneyViewModel
    private let makeSettings: () -> UIViewController
    
    init(viewModel: JourneyViewModel, makeSettings: @escaping () -> UIViewController) {
        self.viewModel = viewModel
        self.makeSettings = makeSettings
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { return nil }
    
    private lazy var settingButton : UIBarButtonItem = {
        let button = UIBarButtonItem(title: "세팅뷰 이동",image: UIImage(named: "setting"), target: self, action: #selector(tabSettingBTN))
        return button
    }()
    
    private lazy var writeDiaryButton : UIButton = {
        var config = UIButton.Configuration.plain()
        let button = UIButton(configuration: config)
        button.setImage(UIImage(named: "writeLight"), for: .normal)
        button.addTarget(self, action: #selector(tabWriteDiaryBTN), for: .touchUpInside)
        return button
    }()
    
    private lazy var honorVCButton : UIBarButtonItem = {
        let honorVCButton = UIBarButtonItem(title: "", image: UIImage(named: "honor"), target: self, action: #selector(honorVCBTN))
        return honorVCButton
    }()
    
    private lazy var monthLabel: UILabel = {
        let monthLabel = UILabel()
        monthLabel.font = UIFont(name: "SFProDisplay-Bold", size: 25)
        monthLabel.textColor = .white
        return monthLabel
    }()
    
    private lazy var countLabel: UILabel = {
        let countLabel = UILabel()
        countLabel.font = UIFont(name: "SFProDisplay-Regular", size: 16)
        countLabel.textColor = .white
        return countLabel
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
        countLabel.text = "\(viewModel.numberOfDaysInCurrentMonth)일 중 \(month.days.count)개 작성했어요."
        sceneLabel.text = JourneySceneCatalog.scene(for: month.month).title
        scene.rootView = makeSceneView()
    }
    
    private func makeSceneView() -> JourneySceneView {
        let month = viewModel.currentMonth
        return JourneySceneView(scene: JourneySceneCatalog.scene(for: month.month), litCount: month.days.count,
                                slotCount: viewModel.numberOfDaysInCurrentMonth, animatesLighting: true)
    }
    
    @objc private func tabSettingBTN() {
        let settingVC = makeSettings()
        settingVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(settingVC, animated: true)
    }
    
    @objc private func tabWriteDiaryBTN() {
        let writeDiaryVC = WriteDiaryVC()
        writeDiaryVC.enterDiary(to: .writeNewDiary)
        writeDiaryVC.delegate = self
        writeDiaryVC.modalPresentationStyle = .automatic
        self.present(writeDiaryVC, animated: true)
    }
    
    @objc private func honorVCBTN() {
        let honorVC = JourneyCollectionHostingController(viewModel: viewModel)
        honorVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(honorVC, animated: true)
    }
    
    func addSubview() {
        addChild(scene)
        view.addSubview(scene.view)
        scene.didMove(toParent: self)
        scene.view.backgroundColor = .clear
        // The sky fills the screen behind the navigation bar, as the old background image did.
        scene.safeAreaRegions = []
        view.addSubview(writeDiaryButton)
        view.addSubview(monthLabel)
        view.addSubview(countLabel)
        view.addSubview(sceneLabel)
        [monthLabel, countLabel, sceneLabel].forEach {
            $0.layer.shadowColor = UIColor.black.cgColor
            $0.layer.shadowOpacity = 0.3
            $0.layer.shadowRadius = 3
            $0.layer.shadowOffset = .zero
        }
    }
    
    func autoLayout() {
        scene.view.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        writeDiaryButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-10)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-32)
        }
        monthLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
        }
        countLabel.snp.makeConstraints { make in
            make.top.equalTo(monthLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
        sceneLabel.snp.makeConstraints { make in
            make.top.equalTo(countLabel.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
        }
    }
    
    private func setNavigationBar() {
        navigationItem.rightBarButtonItem = settingButton
        navigationItem.leftBarButtonItem = honorVCButton
        navigationController?.navigationBar.tintColor = .white
    }
}

extension MotivationVC : DiaryUpdateDelegate {
    func diaryDidUpdate() {
        // The live subscription already reflects the saved diary; only a failed one needs a new start.
        if viewModel.state == .failed { viewModel.retry() }
    }
}
