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
        // Date labels: Saturday blue, Sunday/public holiday red (system colors adapt to dark mode).
        static let saturday = Color(.systemBlue)
        static let holiday = Color(.systemRed)
        static let onboardingBackground = Color("onboardingBackground")

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
}
