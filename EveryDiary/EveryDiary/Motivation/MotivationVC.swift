//
//  MotivationVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import UIKit

import Observation
import SnapKit

class MotivationVC: UIViewController {
    private let buildings = BuildingView()
    private let viewModel: JourneyViewModel
    private let makeSettings: () -> UIViewController
    
    init(viewModel: JourneyViewModel, makeSettings: @escaping () -> UIViewController) {
        self.viewModel = viewModel
        self.makeSettings = makeSettings
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { return nil }
    
    private lazy var background : UIImageView = {
        let background = UIImageView(image: UIImage(named: "View.Background"))
        return background
    }()
    
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
        buildings.showWindows(for: month.days)
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
        let honorVC = HonorVC(viewModel: viewModel)
        honorVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(honorVC, animated: true)
    }
    
    func addSubview() {
        view.addSubview(background)
        view.addSubview(buildings)
        view.addSubview(writeDiaryButton)
        view.addSubview(monthLabel)
        view.addSubview(countLabel)
    }
    
    func autoLayout() {
        background.snp.makeConstraints{ make in
            make.top.bottom.leading.trailing.equalToSuperview()
        }
        writeDiaryButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-10)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-32)
        }
        buildings.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalTo(view.safeAreaLayoutGuide)
        }
        monthLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.centerX.equalToSuperview()
        }
        countLabel.snp.makeConstraints { make in
            make.top.equalTo(monthLabel.snp.bottom).offset(16)
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
