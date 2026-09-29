import UIKit

/// The nickname editor used by settings and right after sign-in.
enum NicknameAlert {
    static func make(title: String, message: String?, current: String?, cancelTitle: String,
                     onSave: @escaping (String) -> Void, onCancel: (() -> Void)? = nil) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = current
            field.placeholder = "닉네임 (최대 \(Nickname.maxLength)자)"
            field.clearButtonMode = .whileEditing
            field.returnKeyType = .done
        }
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in onCancel?() })
        alert.addAction(UIAlertAction(title: "저장", style: .default) { [weak alert] _ in
            onSave(alert?.textFields?.first?.text ?? "")
        })
        return alert
    }

    static func problemMessage(_ problem: Nickname.Problem) -> String {
        switch problem {
        case .empty: return "닉네임을 입력해주세요."
        case .tooLong: return "닉네임은 \(Nickname.maxLength)자까지 입력할 수 있어요."
        }
    }
}
