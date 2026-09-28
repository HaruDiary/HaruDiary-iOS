import SwiftUI
import UIKit

/// A white symbol on a soft gradient, tuned to the app's purple palette.
struct ProfileAvatarView: View {
    /// nil draws the signed-out/guest placeholder.
    let avatar: ProfileAvatar?
    var size: CGFloat = 50

    var body: some View {
        let style = Self.style(for: avatar)
        ZStack {
            Circle().fill(LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(.white.opacity(0.35), lineWidth: max(1, size / 40))
            Image(systemName: style.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: size / 30, y: size / 50)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// For UIKit cells: the same drawing as an image.
    @MainActor
    static func image(for avatar: ProfileAvatar?, size: CGFloat, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: ProfileAvatarView(avatar: avatar, size: size))
        renderer.scale = scale
        return renderer.uiImage
    }

    private struct Style {
        let symbol: String
        let colors: [Color]
    }

    private static func style(for avatar: ProfileAvatar?) -> Style {
        switch avatar {
        case .moon: Style(symbol: "moon.stars.fill", colors: [rgb(0x21005D), rgb(0x7223D8)])
        case .sparkles: Style(symbol: "sparkles", colors: [rgb(0x7223D8), rgb(0xD0BCFF)])
        case .leaf: Style(symbol: "leaf.fill", colors: [rgb(0x4F7A5A), rgb(0xA9C8A3)])
        case .cloud: Style(symbol: "cloud.fill", colors: [rgb(0x5B7FA6), rgb(0xB9CDE3)])
        case .sun: Style(symbol: "sun.max.fill", colors: [rgb(0xD9825B), rgb(0xF4C9A0)])
        case .book: Style(symbol: "book.closed.fill", colors: [rgb(0x4A2C63), rgb(0x9E7CC0)])
        case .cup: Style(symbol: "cup.and.saucer.fill", colors: [rgb(0x6E4E3E), rgb(0xC39C7F)])
        case .heart: Style(symbol: "heart.fill", colors: [rgb(0xB04A70), rgb(0xEFA3BE)])
        case nil: Style(symbol: "person.fill", colors: [rgb(0x9A94A3), rgb(0xCFCAD6)])
        }
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
