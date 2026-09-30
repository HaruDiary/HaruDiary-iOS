import UIKit

extension SettingsModule {
    func makeViewController() -> UIViewController {
        SettingsHostingController(module: self)
    }
}
