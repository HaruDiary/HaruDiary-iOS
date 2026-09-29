//
//  MainVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import Observation
import UIKit

import SnapKit

// 사용자가 작성한 일기 리스트를 보여주는 ViewController
class DiaryListVC: UIViewController, UIAdaptivePresentationControllerDelegate {
    private let viewModel: DiaryListViewModel
    private let makeWriteDiary: MakeWriteDiary
    // The collection view reads this copy so its counts only change together with reloadData().
    private var displayedSections: [DiaryListSection] = []
    private var showsUploadingCell = false

    init(viewModel: DiaryListViewModel, makeWriteDiary: @escaping MakeWriteDiary) {
        self.viewModel = viewModel
        self.makeWriteDiary = makeWriteDiary
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }
        
    // 화면 구성 요소 정의
    private lazy var themeLabel : UILabel = {
        let label = UILabel()
        label.text = "하루일기"
        label.font = UIFont(name: "SFProDisplay-Bold", size: 25)
        label.textColor = .mainTheme
        return label
    }()
    
    // NavigationBar Item
    private lazy var searchBar: UISearchBar = {
        let bounds = UIScreen.main.bounds
        let width = bounds.size.width - 130
        let searchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: width, height: 0))
        searchBar.placeholder = "찾고싶은 일기를 검색하세요."
        searchBar.delegate = self
        return searchBar
    }()
    private lazy var magnifyingButton = setNavigationItem(
        imageNamed: "search",
        titleText: "돋보기",
        for: #selector(magnifyingButtonTapped)
    )
    private lazy var settingButton = setNavigationItem(
        imageNamed: "setting",
        titleText: "세팅뷰 이동",
        for: #selector(tabSettingBTN)
    )
    private lazy var cancelButton = setNavigationItem(
        imageNamed: "",
        titleText: "취소",
        for: #selector(cancelButtonTapped)
    )
    
    // 일기 작성 버튼
    private lazy var writeDiaryButton : UIButton = {
        var config = UIButton.Configuration.plain()
        let button = UIButton(configuration: config)
        button.layer.shadowRadius = 3
        button.layer.borderColor = UIColor(named: "mainCell")?.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 0)
        button.setImage(UIImage(named: "write"), for: .normal)
        button.addTarget(self, action: #selector(tabWriteDiaryButton), for: .touchUpInside)
        return button
    }()
    
    // 컬렉션 뷰 구성
    private lazy var journalCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.layer.cornerRadius = 0
        collectionView.backgroundColor = .clear
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(JournalCollectionViewCell.self, forCellWithReuseIdentifier: JournalCollectionViewCell.reuseIdentifier)
        collectionView.register(HeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: HeaderView.reuseIdentifier)
        collectionView.register(LoadingIndicatorCell.self, forCellWithReuseIdentifier: LoadingIndicatorCell.reuseIdentifier)
        collectionView.refreshControl = refreshControl
        return collectionView
    }()
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        return refreshControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        addSubviews()
        setLayout()
        setNavigationBar()
        journalCollectionView.prefetchDataSource = self
        observeViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The login state now comes from the shared user session instead of a notification.
        viewModel.start()
    }
}

// MARK: - Refresh
extension DiaryListVC {
    @objc private func handleRefresh(_ refreshControl: UIRefreshControl) {
        // The list is live; pulling re-subscribes, which also recovers from a failed load.
        viewModel.retry()
        refreshControl.endRefreshing()
    }

    private func observeViewModel() {
        withObservationTracking {
            _ = viewModel.sections
            _ = viewModel.isUploadingDiary
            _ = viewModel.notice
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render()
                self?.observeViewModel()
            }
        }
        render()
    }

    private func render() {
        displayedSections = viewModel.sections
        showsUploadingCell = viewModel.isUploadingDiary
        journalCollectionView.reloadData()
        if let notice = viewModel.notice {
            viewModel.notice = nil
            switch notice {
            case .movedToTrash:
                TemporaryAlert.presentTemporaryMessage(with: "삭제 완료", message: "휴지통으로 이동하였습니다.", interval: 1.0, for: self)
            case .trashFailed:
                TemporaryAlert.presentTemporaryMessage(with: "삭제 실패", message: "휴지통으로 이동하지 못했습니다.\n잠시 후 다시 시도해주세요.", interval: 1.5, for: self)
            }
        }
    }

    // The uploading cell gets its own first section so diary index paths never shift.
    private var diarySectionOffset: Int { showsUploadingCell ? 1 : 0 }

    private func isUploadingCell(_ indexPath: IndexPath) -> Bool {
        showsUploadingCell && indexPath.section == 0
    }

    private func diary(at indexPath: IndexPath) -> DiaryEntry? {
        guard !isUploadingCell(indexPath),
              let section = displayedSections.safeFetch(at: indexPath.section - diarySectionOffset) else { return nil }
        return section.entries.safeFetch(at: indexPath.item)
    }
}

// MARK: - loadDiaries메서드, navigation관련
extension DiaryListVC {
    
    // NavigationBar 아이템 및 색상 설정
    private func setNavigationBar() {
        self.navigationController?.navigationBar.tintColor = .mainTheme
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationItem.rightBarButtonItems = [settingButton, magnifyingButton]
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: themeLabel)
    }
    // NavigationBar Item 생성 메서드
    private func setNavigationItem(imageNamed name: String, titleText: String, for action: Selector) -> UIBarButtonItem {
        var config = UIButton.Configuration.plain()
        if name == "" {
            config.title = titleText
        } else {
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15)
            config.image = UIImage(named: name)
        }
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.titleLabel?.font = UIFont(name: "SFProDisplay-Bold", size: 20)
        return UIBarButtonItem(customView: button)
    }
    
    @objc private func magnifyingButtonTapped() {
        adjustSearchBarWidth()  // searchBar 크기 조절
        navigationItem.leftBarButtonItems = [UIBarButtonItem(customView: searchBar)]
        navigationItem.rightBarButtonItems = [settingButton, cancelButton]
        searchBar.becomeFirstResponder()
    }
    @objc private func cancelButtonTapped() {
        navigationItem.leftBarButtonItems = [UIBarButtonItem(customView: themeLabel)]
        navigationItem.rightBarButtonItems = [settingButton, magnifyingButton]
        searchBar.text = ""
        searchBar.resignFirstResponder() // 키보드 숨김
        viewModel.query = ""
    }
    @objc private func tabWriteDiaryButton() {
        let writeDiaryVC = makeWriteDiary()
        writeDiaryVC.enterDiary(to: .writeNewDiary)
        writeDiaryVC.delegate = self
        writeDiaryVC.loadingDiaryDelegate = self
        writeDiaryVC.modalPresentationStyle = .automatic
        writeDiaryVC.presentationController?.delegate = self
        self.present(writeDiaryVC, animated: true)
    }
    // 설정 화면(SettingVC)으로 이동
    @objc private func tabSettingBTN() {
        let settingVC = SettingVC(makeWriteDiary: makeWriteDiary)
        settingVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(settingVC, animated: true)
    }
}

// MARK: CollectionViewDataSource
extension DiaryListVC: UICollectionViewDataSource {
    // 섹션 : 월 구분 (업로드 중이면 로딩 셀 섹션이 맨 앞에 추가된다)
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return displayedSections.count + diarySectionOffset
    }
    
    // 월 별 아이템(일기) 수 반환
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if showsUploadingCell && section == 0 { return 1 }
        return displayedSections.safeFetch(at: section - diarySectionOffset)?.entries.count ?? 0
    }
    
    // 셀 구성
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if isUploadingCell(indexPath) {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LoadingIndicatorCell.reuseIdentifier, for: indexPath) as? LoadingIndicatorCell else {
                fatalError("Unable to dequeue LoadingIndicatorCell")
            }
            return cell
        }
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: JournalCollectionViewCell.reuseIdentifier, for: indexPath) as? JournalCollectionViewCell else {
            fatalError("Unable to dequeue JournalCollectionViewCell")
        }
        guard let diary = diary(at: indexPath),
              let date = DateFormatter.yyyyMMddHHmmss.date(from: diary.dateString) else { return cell }
        
        cell.setJournalCollectionViewCell(
            title: diary.title,
            content: diary.content,
            weather: diary.weather,
            emotion: diary.emotion,
            date: DateFormatter.yyyyMMDD.string(from: date)
        )
        
        // DiaryEntry의 첫번째 이미지를 호출
        if let firstImageUrlString = diary.imageURL?.first, let imageUrl = URL(string: firstImageUrlString) {
            // setImage로 이미지와 URL을 함께 전달하여 잘못된 indexPath에 이미지가 전달되는 현상 방지
            cell.loadImageAsync(url: imageUrl) { image in
                if cell.loadingImageURL == imageUrl {
                    cell.setImage(image, for: imageUrl)
                }
            }
        } else {
            // 이미지 URL이 없을 경우 imageView를 숨김
            cell.hideImage()
        }
        return cell
    }
    
    // 헤더뷰 구성
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: HeaderView.reuseIdentifier, for: indexPath) as? HeaderView else {
            fatalError("Invalid view type")
        }
        headerView.headerLabel.text = displayedSections.safeFetch(at: indexPath.section - diarySectionOffset)?.id
        return headerView
    }
    
    // didSelectItemAt
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 로딩 인디케이터 셀 선택 시 임시 메세지를 띄워주도록 처리
        if isUploadingCell(indexPath) {
            TemporaryAlert.presentTemporaryMessage(with: "저장 중", message: "일기를 저장 중입니다.\n잠시만 기다려주세요.", interval: 1.0, for: self)
            return
        }
        guard let diary = diary(at: indexPath) else { return }
        
        // 선택된 일기 정보를 전달하고, 수정(allowEdit) 버튼을 활성화
        let writeDiaryVC = makeWriteDiary()
        writeDiaryVC.enterDiary(to: .showDiary, with: diary)
        writeDiaryVC.delegate = self
        
        // 일기 수정 화면으로 전환
        writeDiaryVC.modalPresentationStyle = .automatic
        // 0.2초 후에 일기 수정 화면으로 전환
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.present(writeDiaryVC, animated: true, completion: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}

//MARK: - Prefetch
extension DiaryListVC: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard let diary = diary(at: indexPath) else { continue }
            
            // DiaryEntry의 imageURL배열에서 첫번째 url을 사용하여 이미지를 prefetching
            if let firstImageUrlString = diary.imageURL?.first, let imageURL = URL(string: firstImageUrlString) {
                ImageCacheManager.shared.loadImage(from: imageURL) { _ in
                    // 이미지를 로드하기 위한 부분. 현재 완료 콜백에서 UI업데이트는 필요하지 않음.
                }
            }
        }
    }
}

extension Array {
    func safeFetch(at index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: Context Menu 관련
extension DiaryListVC {
    // preview가 없는 contextMenu
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let diary = diary(at: indexPath) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions -> UIMenu? in
            // "수정" 액션 생성
            let editAction = UIAction(title: "수정", image: UIImage(systemName: "pencil")) { action in
                // "수정" 선택 시, 일기를 WriteDiaryVC로 전달하고 업데이트 버튼 활성화
                let writeDiaryVC = self.makeWriteDiary()
                writeDiaryVC.enterDiary(to: .editDiary, with: diary)
                writeDiaryVC.delegate = self
                writeDiaryVC.modalPresentationStyle = .automatic
                DispatchQueue.main.async {
                    self.present(writeDiaryVC, animated: true, completion: nil)
                }
            }
            // "휴지통" 액션 생성
            let deleteAction = UIAction(title: "휴지통", image: UIImage(systemName: "trash"), attributes: .destructive) { action in
                // 결과 메세지는 저장 성공/실패가 확인된 뒤 ViewModel의 notice로 표시
                Task { await self.viewModel.moveToTrash(diary) }
            }
            // "수정"과 "삭제" 액션을 포함하는 메뉴 생성
            return UIMenu(title: "", children: [editAction, deleteAction])
        }
    }
}

extension DiaryListVC: UICollectionViewDelegateFlowLayout {
    // 헤더의 크기 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if showsUploadingCell && section == 0 { return .zero }
        return CGSize(width: collectionView.bounds.width, height: 15)
    }
    // 셀의 크기 설정
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = journalCollectionView.bounds.width - 32.0
        let height = journalCollectionView.bounds.height / 4.2
        return CGSize(width: width, height: height)
    }
}

//MARK: SearchBar 관련 메서드
extension DiaryListVC: UISearchBarDelegate {
    // 전체 기록 구독을 메모리에서 거르므로 입력마다 즉시 반영한다(추가 조회·디바운스 불필요).
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.query = searchText
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder() // 키보드 숨김
        viewModel.query = ""
    }
    
    // searchBar의 적절한 사이즈 조절하는 메서드
    private func adjustSearchBarWidth() {
        let screenWidth = UIScreen.main.bounds.width
        var rightItemsWidth: CGFloat = 0
        let spaceBetweenItem: CGFloat = 16  // 버튼 사이의 여백
        let horizontalPadding:CGFloat = 32  // 화면 가장자리에서 searchBar까지의 여잭
        
        // rightNarButtonItems의 너비 계산
        if let rightItems = self.navigationItem.rightBarButtonItems {
            for item in rightItems {
                if let customView = item.customView {
                    rightItemsWidth += customView.frame.width
                } else {
                    // 커스텀 뷰가 없는 경우 기본 너비 추정치 추가
                    rightItemsWidth += 44   // UIBarButtonItem의 추정 평균 너비
                }
            }
            // 버튼 사이의 여백 추가
            rightItemsWidth += CGFloat(rightItems.count - 1) * spaceBetweenItem
        }
        // searchBar의 새로운 너비 계산
        let searchBarWidth = screenWidth - rightItemsWidth - horizontalPadding
        
        // searchBar의 frame 업데이트
        self.searchBar.frame = CGRect(x: 0, y: 0, width: searchBarWidth, height: 0)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: searchBar)
    }
}

// MARK: addSubViews, autoLayout
extension DiaryListVC {
    private func addSubviews() {
        view.addSubview(journalCollectionView)
        view.addSubview(writeDiaryButton)
    }
    
    private func setLayout() {
        journalCollectionView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide).offset(0)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide).offset(0)
            make.leading.equalTo(self.view.safeAreaLayoutGuide).offset(0)
            make.trailing.equalTo(self.view.safeAreaLayoutGuide).offset(0)
        }
        writeDiaryButton.snp.makeConstraints { make in
            make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-10)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-32)
        }
    }
}

//MARK: - 일기 작성, 수정 시 data reload
extension DiaryListVC : DiaryUpdateDelegate {
    func diaryDidUpdate() {
        // The live subscription already reflects saved changes; only recover a failed load.
        if viewModel.state == .failed { viewModel.retry() }
    }
}

extension DiaryListVC: UICollectionViewDelegate {}

//MARK: - Indicator Cell 노출 플래그 수정
extension DiaryListVC: WriteDiaryDelegate {
    func diaryUploadDidStart() {
        viewModel.uploadDidStart()
    }
    
    func diaryUploadDidFinish() {
        viewModel.uploadDidFinish()
    }
}
