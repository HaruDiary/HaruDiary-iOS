//
//  CalendarListVC.swift
//  EveryDiary
//
//  Created by eunsung ko on 2/29/24.
//

import UIKit
import Observation

import SnapKit

class CalendarListVC: UIViewController {
    private let viewModel: CalendarViewModel
    private var selectedDiaries: [DiaryEntry] { viewModel.selectedEntries }

    init(viewModel: CalendarViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    private lazy var dateLabel: UILabel = {
        let dateLabel = UILabel()
        dateLabel.font = UIFont(name: "SFProDisplay-Bold", size: 20)
        dateLabel.textColor = .mainTheme
        return dateLabel
    }()

    private lazy var dailyListCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.layer.cornerRadius = 0
        collectionView.backgroundColor = .mainBackground
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView.register(DailyListCell.self, forCellWithReuseIdentifier: DailyListCell.id)
        collectionView.delegate = self
        collectionView.dataSource = self
        return collectionView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        addSubViewCalendarListVC()
        autoLayoutCalendarListVC()
        observeState()
    }
    
    private func autoLayoutCalendarListVC() {
        dailyListCollectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(0)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(0)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(0)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(0)
        }
    }
    
    private func addSubViewCalendarListVC() {
        view.addSubview(dailyListCollectionView)
        setNavigationBar()
    }
    
    private func setNavigationBar() {
        navigationItem.titleView = dateLabel
    }
    
    private func fetchUpdateDiaries() {
        viewModel.start()
    }

    private func observeState() {
        let formatter = DateFormatter.createFormatter(dateFormat: "yyyy. MM. dd(E)")
        formatter.calendar = viewModel.calendar
        formatter.timeZone = viewModel.calendar.timeZone
        dateLabel.text = formatter.string(from: viewModel.selectedDate)
        dailyListCollectionView.reloadData()
        withObservationTracking {
            _ = viewModel.index
            _ = viewModel.selectedDate
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeState() }
        }
    }
}

extension CalendarListVC : UICollectionViewDataSource,  UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectedDiaries.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DailyListCell.id, for: indexPath) as? DailyListCell else {
            fatalError("Unable to dequeue JournalCollectionViewCell")
        }
        let diary = selectedDiaries[indexPath.row]

        if let date = DateFormatter.yyyyMMddHHmmss.date(from: diary.dateString) {
            let formattedDateString = DateFormatter.yyyyMMdd.string(from: date)
        
        cell.setDailyListCell(title: diary.title, content: diary.content, weather: diary.weather, emotion: diary.emotion, date: formattedDateString)
        }
        
        // 이미지 배열에서 첫 번째 URL을 사용하여 셀의 이미지 뷰 설정
        if let firstImageUrlString = diary.imageURL?.first, let imageUrl = URL(string: firstImageUrlString) {
            cell.imageView.isHidden = false
            
            // ImageCacheManager를 이용해 이미지 캐싱
            ImageCacheManager.shared.loadImage(from: imageUrl) { image in
                DispatchQueue.main.async {
                    if collectionView.indexPath(for: cell) == indexPath {
                        cell.imageView.image = image
                    }
                }
            }
        } else {
            // 이미지 URL이 없을 경우 imageView를 숨김
            cell.imageView.isHidden = true
        }
        return cell
    }
    
    // Cell 선택
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let diary = selectedDiaries[indexPath.row]
        let writeDiaryVC = WriteDiaryVC()
        
        // 선택된 일기 정보를 전달하고, 수정 버튼을 활성화
        writeDiaryVC.enterDiary(to: .showDiary, with: diary)
        writeDiaryVC.delegate = self
        // 일기 수정 화면으로 전환
        writeDiaryVC.modalPresentationStyle = .automatic
        
        self.present(writeDiaryVC, animated: true, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
    
    // 헤더의 크기 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 15)
    }
    // 셀의 크기 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = dailyListCollectionView.bounds.width - 32.0
        let height = dailyListCollectionView.bounds.height / 4.2
        return CGSize(width: width, height: height)
    }
}

//MARK: - 일기 수정 시, data 변화 감지
extension CalendarListVC : DiaryUpdateDelegate {
    func diaryDidUpdate() {
        fetchUpdateDiaries()
    }
}
