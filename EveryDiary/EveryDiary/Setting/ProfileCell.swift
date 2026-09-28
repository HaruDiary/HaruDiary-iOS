//
//  ProfileCell.swift
//  EveryDiary
//
//  Created by eunsung ko on 2/29/24.
//

import UIKit

import SnapKit
import FirebaseAuth

class ProfileCell: UITableViewCell {
    static let id = "ProfileCell"

    private lazy var profileImageView : UIImageView = {
        let profileImageView = UIImageView()
        profileImageView.contentMode = .scaleAspectFit
        return profileImageView
    }()
    
    private lazy var emailLabel : UILabel = {
        let emailLabel = UILabel()
        emailLabel.textColor = .subText
        emailLabel.font = UIFont(name: "SFProRounded-Regular", size: 14)
        // 로그인 방식과 이메일을 두 줄로 표시한다. 긴 이메일은 가운데를 줄인다.
        emailLabel.numberOfLines = 2
        emailLabel.lineBreakMode = .byTruncatingMiddle
        return emailLabel
    }()
    
    private lazy var nameLabel : UILabel = {
        let nameLabel = UILabel()
        nameLabel.textColor = .mainTheme
        nameLabel.font = UIFont(name: "SFProRounded-Bold", size: 24)
        return nameLabel
    }()
    
    // 로그인한 경우 프로필을 눌러 닉네임을 바꿀 수 있음을 알린다.
    private lazy var editImageView: UIImageView = {
        let symbol = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "pencil", withConfiguration: symbol))
        // 이름·아이콘과 같은 앱 기본 색
        imageView.tintColor = .mainTheme
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var loginButton : UIButton = {
        let loginButton = UIButton()
        loginButton.layer.backgroundColor = UIColor(named: "loginBackground")?.cgColor
        loginButton.layer.shadowOpacity = 0.1
        loginButton.layer.shadowColor = UIColor(named: "mainTheme")?.cgColor
        loginButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        loginButton.layer.shadowRadius = 3
        loginButton.layer.cornerRadius = 10
        loginButton.setTitleColor(.mainCell, for: .normal)
        loginButton.setTitle("로그인", for: .normal)
        loginButton.addTarget(self, action: #selector(loginButtonTouchDown), for: .touchDown)
        loginButton.addTarget(self, action: #selector(loginButtonTouchOutside), for: .touchUpInside)
        return loginButton
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: ProfileCell.id)
        self.selectionStyle = .none
        contentView.layer.cornerRadius = 10
        contentView.layer.shadowOpacity = 0.1
        contentView.layer.shadowColor = UIColor(named: "mainTheme")?.cgColor
        contentView.layer.shadowRadius = 3
        contentView.layer.shadowOffset = CGSize(width: 0, height: 0)
        contentView.layer.backgroundColor = UIColor(named: "mainCell")?.cgColor
        addSubViewProfileCell()
        autoLayoutProfileCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func loginButtonTouchDown() {
        loginButton.layer.backgroundColor = UIColor(named: "subBackground")?.cgColor
    }
    
    @objc private func loginButtonTouchOutside() {
        loginButton.layer.backgroundColor = UIColor(named: "loginBackground")?.cgColor
    }
    
    private func addSubViewProfileCell() {
        addSubview(emailLabel)
        addSubview(nameLabel)
        addSubview(profileImageView)
        addSubview(loginButton)
        addSubview(editImageView)
    }
    
    private func autoLayoutProfileCell() {
        profileImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(50)
        }
        nameLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview().offset(-20)
            make.leading.equalTo(profileImageView.snp.trailing).offset(16)
            make.trailing.equalTo(loginButton.snp.leading).inset(16)
            make.bottom.equalTo(emailLabel.snp.top).offset(-10)
            make.height.equalTo(28)
        }
        emailLabel.snp.makeConstraints { make in
            make.leading.equalTo(profileImageView.snp.trailing).offset(16)
            make.trailing.equalTo(loginButton.snp.leading).inset(16)
        }
        editImageView.snp.makeConstraints { make in
            make.centerY.equalTo(loginButton)
            make.trailing.equalToSuperview().inset(24)
            make.width.height.equalTo(28)
        }
        loginButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(70)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 10, left: 4, bottom: 10, right: 4))
    }
    
    func prapare(email: String?, name: String?, image: String?, isLoggedIn: Bool) {
        // 로그인 방식과 이메일 두 줄 사이를 띄운다.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        paragraph.lineBreakMode = .byTruncatingMiddle
        self.emailLabel.attributedText = email.map { NSAttributedString(string: $0, attributes: [
            .paragraphStyle: paragraph,
            .font: emailLabel.font as Any,
            .foregroundColor: emailLabel.textColor as Any
        ]) }
        self.nameLabel.text = name
        // 선택한 프로필 이미지(없으면 손님용 기본 이미지)를 앱 공용 그림으로 그린다.
        self.profileImageView.image = ProfileAvatarView.image(for: image.flatMap(ProfileAvatar.init(rawValue:)), size: 50,
                                                              scale: max(traitCollection.displayScale, 3))
        if isLoggedIn {
                self.loginButton.isHidden = true
                self.loginButton.isEnabled = false
        } else {
                self.loginButton.isHidden = false
                self.loginButton.isEnabled = true
        }
        editImageView.isHidden = !isLoggedIn
        accessibilityHint = isLoggedIn ? "닉네임을 변경합니다" : nil
    }
}
