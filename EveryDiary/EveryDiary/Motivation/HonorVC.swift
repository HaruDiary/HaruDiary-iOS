//
//  HonorVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/23/24.
//

import UIKit

import Observation
import SnapKit

class HonorVC: UIViewController {
    // Shares the journey tab's model, so this screen adds no diary subscription of its own.
    private let viewModel: JourneyViewModel
    private var months: [JourneyMonth] = []
    
    init(viewModel: JourneyViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { return nil }
    
    private lazy var backgroundImage: UIImageView = {
        let backgroundImage = UIImageView()
        backgroundImage.translatesAutoresizingMaskIntoConstraints = false
        backgroundImage.image = UIImage(named: "honorBackground")
        return backgroundImage
    }()
    
    private lazy var honorCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height / 5)
        layout.scrollDirection = .vertical
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0)
        
        let honorCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        honorCollectionView.backgroundColor = .clear
        honorCollectionView.isScrollEnabled = true
        honorCollectionView.register(honorCollectionViewCell.self, forCellWithReuseIdentifier: honorCollectionViewCell.honorIdentifier)
        honorCollectionView.register(honorHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "honorHeaderViewIdentifier")
        
        return honorCollectionView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        honorCollectionView.delegate = self
        honorCollectionView.dataSource = self
        setNavigationBar()
        addSubView()
        autoLayout()
        observeViewModel()
    }
}

//MARK: - UI 설정
extension HonorVC {
    private func addSubView() {
        view.addSubview(backgroundImage)
        view.addSubview(honorCollectionView)
    }
    
    private func autoLayout() {
        backgroundImage.snp.makeConstraints{ make in
            make.edges.equalToSuperview()
        }
        honorCollectionView.snp.makeConstraints { make in
            make.top.bottom.leading.trailing.equalTo(view.safeAreaLayoutGuide)
        }
    }
}

//MARK: - 데이터
extension HonorVC {
    private func observeViewModel() {
        withObservationTracking {
            months = viewModel.record.months
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeViewModel() }
        }
        honorCollectionView.reloadData()
    }
    
    private func setNavigationBar() {
        navigationController?.navigationBar.tintColor = .black
    }
}

// MARK: - UICollectionViewDataSource
extension HonorVC: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    //섹션 설정
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if months.isEmpty {
            let message = UILabel(frame: CGRect(x: 0, y: 0, width: honorCollectionView.bounds.width, height: honorCollectionView.bounds.height))
            message.text = "당신의 여정을 시작하세요."
            message.font = UIFont(name: "SFProDisplay-Bold", size: 20)
            message.textColor = .black
            message.textAlignment = .center
            honorCollectionView.backgroundView = message
            return 0
        } else {
            honorCollectionView.backgroundView = nil
            return months.count
        }
    }
    
    //셀 설정
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = honorCollectionView.dequeueReusableCell(withReuseIdentifier: honorCollectionViewCell.honorIdentifier, for: indexPath) as? honorCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.images.image = nil
        
        cell.configureImage(withNumberOfDays: months[indexPath.section].days.count)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let month = months[indexPath.section]
        
        let VC = DetailVC()
        VC.yearMonthKey = month.title // 연-월 문자열을 전달합니다.
        VC.selectedData = month.days // 해당하는 일자 세트를 전달합니다.
        VC.modalPresentationStyle = .fullScreen
        self.present(VC, animated: true)

    }
    
    //헤더 설정
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let headerView = honorCollectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: honorHeaderView.honorHeaderIdentifier, for: indexPath) as? honorHeaderView else {
            fatalError("Failed to dequeue honor header view")
        }
        // 정렬된 연-월 데이터를 사용
        headerView.headerLabel.text = months[indexPath.section].title
        return headerView
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 16) // 헤더의 너비와 높이 설정
    }
}

