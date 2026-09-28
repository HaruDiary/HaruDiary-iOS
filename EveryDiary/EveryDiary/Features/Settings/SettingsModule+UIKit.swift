import UIKit

extension SettingsModule {
    func makeViewController() -> UIViewController {
        SettingVC(module: self)
    }
}
