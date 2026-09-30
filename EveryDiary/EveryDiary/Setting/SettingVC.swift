//
//  SettingVC.swift
//  EveryDiary
//
//  Created by t2023-m0044 on 2/21/24.
//

import Observation
import SwiftUI
import UIKit

import SnapKit

class SettingVC: UIViewController {
    
    private let module: SettingsModule
    private var viewModel: SettingsViewModel { module.viewModel }
    
    private var loginStatus: Bool { viewModel.profile.isLoggedIn }
    
    private var dataSource = [CellModel]()
    // 올린 프로필 사진은 한 번 받아 두고, 주소가 바뀔 때만 다시 받는다. 주소에는 접근 토큰이 있어 기록하지 않는다.
    private var profilePhoto: (url: URL, image: UIImage)?
    private var profilePhotoTask: Task<Void, Never>?
    private let appleRequest = AppleAuthorizationRequest()
    
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
        present(SignInHostingController(gateway: module.signInGateway), animated: true)
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
            .profileItem(email: profile.detail, name: profile.name, image: nil, isLoggedIn: profile.isLoggedIn),
            .settingItem(title: "알림", iconImage: "notification", number: 1),
            .settingItem(title: "잠금", iconImage: "lock", number: 2),
            .settingItem(title: "최근 삭제한 항목", iconImage: "trash", number: 3),
            .signOutItem(title: "로그 아웃", iconImage: "logoutRed", number: 1, isLoggedIn: profile.isLoggedIn),
            .signOutItem(title: "회원 탈퇴", iconImage: withdrawalIcon, number: 2, isLoggedIn: profile.isLoggedIn)
        ]
        tableView.reloadData()
        loadProfilePhotoIfNeeded()
    }
    
    private func profileImage() -> UIImage? {
        let scale = max(traitCollection.displayScale, 3)
        switch viewModel.profile.picture {
        case .photo(let url):
            if let profilePhoto, profilePhoto.url == url { return profilePhoto.image }
            return ProfileAvatarView.image(for: viewModel.defaultAvatar, size: 50, scale: scale)
        case .avatar(let avatar):
            return ProfileAvatarView.image(for: avatar, size: 50, scale: scale)
        case nil:
            return ProfileAvatarView.image(for: nil, size: 50, scale: scale)
        }
    }
    
    private func loadProfilePhotoIfNeeded() {
        guard case .photo(let url) = viewModel.profile.picture, profilePhoto?.url != url else { return }
        profilePhotoTask?.cancel()
        profilePhotoTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data),
                  let self, !Task.isCancelled else { return }
            self.profilePhoto = (url, image)
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
        }
    }
    
    private func observeAccount() {
        // 사진·기본 프로필만 바뀌면 계정 정보는 같아 알림이 오지 않으므로 사진도 함께 관찰한다.
        withObservationTracking {
            _ = viewModel.account
            _ = viewModel.picture
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
        case .appleConfirmationFailed:
            presentAlert(title: "회원 탈퇴 실패", message: "로그인한 Apple 계정으로 확인해주세요.\n다른 Apple 계정으로는 탈퇴할 수 없어요.")
        case .appleRevocationFailed:
            presentAlert(title: "회원 탈퇴 실패", message: "Apple 로그인 연결을 해제하지 못해 탈퇴를 멈췄어요.\n일기와 사진은 그대로예요. 잠시 후 다시 시도해주세요.")
        case .dataErasureFailed:
            presentAlert(title: "회원 탈퇴 실패", message: "일기와 사진을 모두 지우지 못해 탈퇴를 멈췄어요.\n잠시 후 다시 시도해주세요.")
        case .deletionFailed:
            presentAlert(title: "회원 탈퇴 실패", message: "회원 탈퇴를 완료하지 못했습니다.\n잠시 후 다시 시도해주세요.")
        case .profileSaved:
            TemporaryAlert.presentTemporaryMessage(with: "저장 완료", message: "프로필을 저장했어요.", interval: 1.0, for: self)
        case .nicknameInvalid(let problem):
            presentAlert(title: "닉네임을 확인해주세요", message: NicknameAlert.problemMessage(problem)) { [weak self] in
                self?.editProfile()
            }
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
        present(SignInHostingController(gateway: module.signInGateway), animated: true)
    }
    
    // Apple 회원은 탈퇴 직전에 Apple로 한 번 더 확인한다. 이 확인으로 Firebase가 Apple 연결을 끊는다.
    private func confirmWithAppleThenDelete() {
        appleRequest.start(from: self) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let apple):
                Task { await self.viewModel.deleteAccount(appleAuthorization: apple) }
            case .failure(AppleAuthorizationRequest.Failure.canceled):
                break
            case .failure:
                self.presentAlert(title: "Apple 확인 실패", message: "Apple 계정을 확인하지 못했어요.\n잠시 후 다시 시도해주세요.")
            }
        }
    }
    
    // 회원 탈퇴 재차 확인
    func showDeleteAccountMessage() {
        let alert = UIAlertController(title: "회원 탈퇴하시겠습니까?", message: "작성한 일기와 사진이 모두 삭제되며 복구할 수 없습니다.\n그래도 진행하시겠습니까?", preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: "회원 탈퇴", style: .destructive) { [weak self] _ in
            guard let self else { return }
            if self.viewModel.needsAppleConfirmationToDelete {
                self.confirmWithAppleThenDelete()
            } else {
                Task { await self.viewModel.deleteAccount() }
            }
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
            
        case let .profileItem(email, name, _, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: ProfileCell.id, for: indexPath) as! ProfileCell
            cell.prapare(email: email, name: name, image: profileImage(), isLoggedIn: loginStatus)
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
                navigationController?.pushViewController(ReminderModule.makeSettingsViewController(), animated: true)
            case 2:
                navigationController?.pushViewController(LockModule.makeSettingsViewController(), animated: true)
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
        case .profileItem:
            // 로그인한 경우 프로필을 누르면 프로필 이미지·닉네임을 바꾼다. 로그인 전에는 로그인 버튼을 사용한다.
            if viewModel.canManageAccount { editProfile() }
        }
    }
    
    private func editProfile() {
        let editor = ProfileEditView(
            nickname: viewModel.nickname, picture: viewModel.profile.picture,
            onSave: { [weak self] nickname, picture in
                guard let self else { return false }
                let saved = await self.viewModel.updateProfile(nickname: nickname, picture: picture)
                // 방금 올린 사진은 이미 가지고 있으므로 다시 받지 않고 바로 보여준다.
                if saved, case .newPhoto(let data) = picture, case .photo(let url) = self.viewModel.profile.picture,
                   let image = UIImage(data: data) {
                    self.profilePhoto = (url, image)
                    self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
                }
                return saved
            },
            onClose: { [weak self] in self?.dismiss(animated: true) }
        )
        let controller = UIHostingController(rootView: editor)
        controller.sheetPresentationController?.detents = [.large()]
        present(controller, animated: true)
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

