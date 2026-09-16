import SwiftUI
import UIKit

enum DiaryTheme {
    enum Colors {
        static let brand = Color("mainTheme")
        static let background = Color("mainBackground")
        static let surface = Color("mainCell")
        static let text = Color("mainText")
        static let secondaryText = Color("SubText")
        static let error = Color("mainError")
        static let selection = Color("subTheme")

        static let brandUIKit = UIColor(named: "mainTheme") ?? .systemPurple
        static let backgroundUIKit = UIColor(named: "mainBackground") ?? .systemBackground
    }

    enum Fonts {
        static let title = Font.title2.weight(.bold)
        static let section = Font.headline
        static let body = Font.body
        static let caption = Font.caption
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let screen: CGFloat = 16
        static let section: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 16
    }

    enum Size {
        static let icon: CGFloat = 24
        static let touchTarget: CGFloat = 44
        static let floatingButton: CGFloat = 56
        static let thumbnail: CGFloat = 80
    }
}
