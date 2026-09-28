//
//  SettingVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import Observation
import UIKit

import SnapKit

class SettingVC: UIViewController {
    
    private let module: SettingsModule
    private var viewModel: SettingsViewModel { module.viewModel }
    
    private var loginStatus: Bool { viewModel.profile.isLoggedIn }
    
    private var dataSource = [CellModel]()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SettingCell.self, forCellReuseIdentifier: SettingCell.id)
        tableView.register(ProfileCell.self, forCellReuseIdentifier: ProfileCell.id)
        tableView.register(SignOutCell.self, forCellReuseIdentifier: SignOutCell.id)
        tableView.isScrollEnabled = true
        tableView.backgroundColor = .mainBackground
        tableView.separatorStyle = .none
        return tableView
    }()
    
    private let deletionProgress: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .mainTheme
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    init(module: SettingsModule) {
        self.module = module
        super.init(nibName: nil, bundle: nil)
    }
    
    // The replaced UIKit tabs (DiaryListVC, CalendarVC) still create settings without dependencies.
    // Remove with those screens; live tabs pass a module from AppDependencies.
    convenience init() {
        self.init(module: AppDependencies.live().makeSettingsModule())
    }
    
    required init?(coder: NSCoder) { return nil }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSubviewsSettingVC()
        autoLayoutSettingVC()
        viewModel.start()
        observeAccount()
        observeNotice()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNavigationBar()
        tableView.selectRow(at: .none,
                            animated: true,
                            scrollPosition: .top)
    }
    
    // Popping settings ends the account observation.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || navigationController?.isBeingDismissed == true {
            viewModel.stop()
        }
    }
    
    private func addSubviewsSettingVC() {
        view.backgroundColor = .mainBackground
        view.addSubview(tableView)
        view.addSubview(deletionProgress)
    }
    
    private func autoLayoutSettingVC() {
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(10)
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(10)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-10)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(10)
        }
        deletionProgress.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    @objc func didTapLoginButton() {
        let loginVC = LoginVC()
        loginVC.modalPresentationStyle = .fullScreen
        self.present(loginVC, animated: true)
    }
    
    private func setNavigationBar() {
        navigationItem.title = "설정"
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "설정", style: .plain, target: nil, action: nil)
        navigationController?.navigationBar.tintColor = .mainTheme
    }
}

// MARK: - 계정 상태 표시 & 로그아웃·회원 탈퇴 결과
extension SettingVC {
    // 로그인 상태 별 TableView의 구성
    private func refresh() {
        let profile = viewModel.profile
        let withdrawalIcon = profile.isLoggedIn ? "withdrawal" : "trash"
        dataSource = [
            .profileItem(email: profile.detail, name: profile.name, image: profile.imageName, isLoggedIn: profile.isLoggedIn),
            .settingItem(title: "알림", iconImage: "notification", number: 1),
            .settingItem(title: "잠금", iconImage: "lock", number: 2),
            .settingItem(title: "최근 삭제한 항목", iconImage: "trash", number: 3),
            .signOutItem(title: "로그 아웃", iconImage: "logoutRed", number: 1, isLoggedIn: profile.isLoggedIn),
            .signOutItem(title: "회원 탈퇴", iconImage: withdrawalIcon, number: 2, isLoggedIn: profile.isLoggedIn)
        ]
        tableView.reloadData()
    }
    
    private func observeAccount() {
        withObservationTracking {
            _ = viewModel.account
            _ = viewModel.isDeletingAccount
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeAccount() }
        }
        refresh()
        // Erasing many diaries and photos takes a while; the screen waits instead of accepting other actions.
        if viewModel.isDeletingAccount {
            deletionProgress.startAnimating()
        } else {
            deletionProgress.stopAnimating()
        }
        view.isUserInteractionEnabled = !viewModel.isDeletingAccount
        navigationItem.hidesBackButton = viewModel.isDeletingAccount
    }
    
    private func observeNotice() {
        withObservationTracking {
            _ = viewModel.notice
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeNotice() }
        }
        showNoticeIfNeeded()
    }
    
    private func showNoticeIfNeeded() {
        guard let notice = viewModel.notice else { return }
        viewModel.notice = nil
        switch notice {
        case .signedOut:
            // 여정 화면은 아직 이 알림으로 사용자 변경을 반영한다.
            NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
            presentAlert(title: "확인", message: "로그아웃이 완료되었습니다.") { [weak self] in self?.showMainScreen() }
        case .signOutFailed:
            presentAlert(title: "로그아웃 실패", message: "로그아웃하지 못했습니다.\n잠시 후 다시 시도해주세요.")
        case .accountDeleted:
            NotificationCenter.default.post(name: .loginstatusChanged, object: nil)
            presentAlert(title: "회원 탈퇴", message: "회원 탈퇴가 완료되었습니다.") { [weak self] in self?.showMainScreen() }
        case .deletionNeedsRecentLogin:
            presentAlert(title: "다시 로그인이 필요해요", message: "보안을 위해 로그아웃 후 다시 로그인한 뒤\n바로 탈퇴해주세요.")
        case .dataErasedNeedsRecentLogin:
            presentAlert(title: "탈퇴를 마치려면 다시 로그인해주세요", message: "일기와 사진은 모두 삭제되었어요.\n로그아웃 후 다시 로그인한 뒤 탈퇴를 한 번 더 눌러주세요.")
        case .dataErasureFailed:
            presentAlert(title: "회원 탈퇴 실패", message: "일기와 사진을 모두 지우지 못해 탈퇴를 멈췄어요.\n잠시 후 다시 시도해주세요.")
        case .deletionFailed:
            presentAlert(title: "회원 탈퇴 실패", message: "회원 탈퇴를 완료하지 못했습니다.\n잠시 후 다시 시도해주세요.")
        }
    }
    
    private func presentAlert(title: String, message: String, onConfirm: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in onConfirm?() })
        present(alert, animated: true)
    }
    
    // 사용자 로그아웃 재차 확인
    private func signOutAlert() {
        let alertController = UIAlertController(title: "알림", message: "로그아웃 하시겠습니까?", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.viewModel.signOut()
        }
        alertController.addAction(okAction)
        
        let cancelAction = UIAlertAction(title: "취소", style: .cancel)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func showMainScreen() {
        let loginVC = LoginVC()
        loginVC.modalPresentationStyle = .fullScreen
        self.present(loginVC, animated: true)
    }
    
    // 회원 탈퇴 재차 확인
    func showDeleteAccountMessage() {
        let alert = UIAlertController(title: "회원 탈퇴하시겠습니까?", message: "작성한 일기와 사진이 모두 삭제되며 복구할 수 없습니다.\n그래도 진행하시겠습니까?", preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: "회원 탈퇴", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task { await self.viewModel.deleteAccount() }
        }
        let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - TableView 구성
extension SettingVC : UITableViewDelegate, UITableViewDataSource {
    // TableView의 Cell 갯수는 datasource의 조건에 따라 달라진다
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    // 각 cell 별 커스텀
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch self.dataSource[indexPath.row] {
            
        case let .profileItem(email, name, image, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: ProfileCell.id, for: indexPath) as! ProfileCell
            cell.prapare(email: email, name: name, image: image, isLoggedIn: loginStatus)
            cell.backgroundColor = .mainBackground
            cell.loginButton.addTarget(self, action: #selector(didTapLoginButton), for: .touchUpInside)
            return cell
            
        case let .settingItem(title, iconImage, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingCell.id, for: indexPath) as! SettingCell
            cell.prepare(title: title, iconImage: iconImage)
            cell.backgroundColor = .mainBackground
            return cell
            
        case let .signOutItem(title, iconImage, _, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: SignOutCell.id, for: indexPath) as! SignOutCell
            cell.prepare(title: title, iconImage: iconImage, isLoggedIn: loginStatus)
            cell.backgroundColor = .mainBackground
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedItem = dataSource[indexPath.row]
        
        switch selectedItem {
        case .settingItem(_, _, let number):
            switch number {
            case 1:
                let notificationVC = NotificationVC()
                navigationController?.pushViewController(notificationVC, animated: true)
            case 2:
                let lockVC = LockVC()
                navigationController?.pushViewController(lockVC, animated: true)
            case 3:
                let trashVC = module.makeTrashModule().makeViewController()
                navigationController?.pushViewController(trashVC, animated: true)
            default:
                print("error")
            }
        case .signOutItem(_, _, let number, _):
            switch number {
            case 1:
                signOutAlert()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // 0.5초 후에 실행
                    tableView.deselectRow(at: indexPath, animated: true)
                }
                print("로그아웃")
            case 2:
                print("회원 탈퇴")
                showDeleteAccountMessage()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // 0.5초 후에 실행
                    tableView.deselectRow(at: indexPath, animated: true)
                }
            default:
                print("Error")
            }
        default:
            print("No Any Action")
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = dataSource[indexPath.row]
        switch item {
        case .profileItem(_, _, _, _):
            return 133
        case .settingItem(_, _, _):
            return 100
        case .signOutItem(_, _, _, isLoggedIn: false):
            return 0
        default:
            return 100
        }
    }
}

