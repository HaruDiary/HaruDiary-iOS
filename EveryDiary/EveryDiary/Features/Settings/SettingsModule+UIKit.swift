import UIKit

extension SettingsModule {
    func makeViewController(makeWriteDiary: @escaping MakeWriteDiary) -> UIViewController {
        SettingsHostingController(module: self, makeWriteDiary: makeWriteDiary)
    }
}
