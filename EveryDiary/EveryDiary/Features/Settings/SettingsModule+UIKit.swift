import UIKit

extension SettingsModule {
    func makeViewController(makeWriteDiary: @escaping MakeWriteDiary) -> UIViewController {
        SettingVC(module: self, makeWriteDiary: makeWriteDiary)
    }
}
