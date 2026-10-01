import SwiftUI
import UIKit

enum DiaryTheme {
    enum Colors {
        static let brand = Color("mainTheme")
        static let background = Color("mainBackground")
        /// Text and icons on `brand`: white in light mode, the deep purple on dark mode's light purple.
        static let onBrand = Color("onTheme")
        static let surface = Color("mainCell")
        static let text = Color("mainText")
        static let secondaryText = Color("SubText")
        static let error = Color("mainError")
        static let selection = Color("subTheme")
        // Date labels: Saturday blue, Sunday/public holiday red (system colors adapt to dark mode).
        static let saturday = Color(.systemBlue)
        static let holiday = Color(.systemRed)
        static let onboardingBackground = Color("onboardingBackground")

        static let brandUIKit = UIColor(named: "mainTheme") ?? .systemPurple
        static let backgroundUIKit = UIColor(named: "mainBackground") ?? .systemBackground
    }

    enum Fonts {
        static let title = Font.title2.weight(.bold)
        /// The title at the top of each tab (하루일기, 캘린더), larger and heavier than screen titles.
        static let tabTitle = Font.system(.largeTitle, design: .default).weight(.heavy)
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

    enum TabHeader {
        /// Space above the tab title, the same on every tab so titles and the settings button line up.
        static let top: CGFloat = 12
    }

    enum Radius {
        static let card: CGFloat = 16
    }

    enum Size {
        static let icon: CGFloat = 24
        static let touchTarget: CGFloat = 44
        /// The write button uses the original `write` artwork at the size and place of the journey tab's button.
        static let floatingButton: CGFloat = 65
        static let floatingButtonTrailing: CGFloat = 22
        static let floatingButtonBottom: CGFloat = 39
        /// Space scrolling content leaves at the bottom so the write button never covers the last item.
        static let floatingButtonClearance: CGFloat = floatingButton + floatingButtonBottom + 12
        static let thumbnail: CGFloat = 80
    }

    enum Onboarding {
        static let contentWidth: CGFloat = 560
        static let illustrationMaxHeight: CGFloat = 360
        static let illustrationMinHeight: CGFloat = 180
        static let buttonHeight: CGFloat = 56
        static let title = Font.system(.title2, design: .rounded).weight(.bold)
        static let pageDuration = 0.32
        static let pressDuration = 0.15
    }

    enum SignIn {
        static let contentWidth: CGFloat = 480
        static let title = Font.system(size: 40, weight: .heavy, design: .rounded)
        static let illustrationMaxHeight: CGFloat = 260
        static let buttonHeight: CGFloat = 52
        static let buttonRadius: CGFloat = 12
        static let providerLogo: CGFloat = 20
    }

    enum Lock {
        static let keySize: CGFloat = 76
        static let keySpacing: CGFloat = 20
        static let dotSize: CGFloat = 14
        static let dotSpacing: CGFloat = 20
        static let headerIcon: CGFloat = 64
        static let keyFont = Font.system(.title, design: .rounded).weight(.medium)
    }
}
