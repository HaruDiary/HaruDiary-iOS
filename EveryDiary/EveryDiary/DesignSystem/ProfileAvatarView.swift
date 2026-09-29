import SwiftUI
import UIKit

/// The app's original profile drawing (outlined head and body in a ring), in color variants.
/// Drawn as vectors on the original 24 × 24 grid so it stays sharp from 50 pt to 104 pt.
struct ProfileAvatarView: View {
    /// nil draws the signed-out/guest placeholder.
    let avatar: ProfileAvatar?
    var size: CGFloat = 50

    var body: some View {
        let palette = Self.palette(for: avatar)
        Canvas { context, canvas in
            let unit = canvas.width / 24
            func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (x - r) * unit, y: (y - r) * unit, width: 2 * r * unit, height: 2 * r * unit))
            }
            let face = circle(12, 12, 11)
            context.clip(to: face)
            context.fill(face, with: .color(palette.background))
            context.fill(circle(12, 22, 8), with: .color(Self.outline))
            context.fill(circle(12, 22, 6), with: .color(palette.body))
            context.fill(circle(12, 9, 4), with: .color(Self.outline))
            context.fill(circle(12, 9, 2), with: .color(palette.head))
            context.stroke(circle(12, 12, 10), with: .color(Self.outline), lineWidth: 2 * unit)
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

    private static let outline = rgb(0x2C1170)
    private static let yellow = rgb(0xFAC700)

    private struct Palette {
        let background: Color
        let body: Color
        var head: Color = ProfileAvatarView.yellow
    }

    // google/apple are the colors of the original assets; the others reuse the same outline and head.
    private static func palette(for avatar: ProfileAvatar?) -> Palette {
        switch avatar {
        case .google: Palette(background: rgb(0x39AB54), body: rgb(0x6A91C9))
        case .apple: Palette(background: rgb(0x6A91C9), body: rgb(0xEA4D35))
        case .lavender: Palette(background: rgb(0xD0BCFF), body: rgb(0x7223D8))
        case .mint: Palette(background: rgb(0x7FD1C5), body: rgb(0xEA4D35))
        case .peach: Palette(background: rgb(0xF6B38E), body: rgb(0x6A91C9))
        case .pink: Palette(background: rgb(0xF4A3C0), body: rgb(0x39AB54))
        case .sky: Palette(background: rgb(0x9BD4F5), body: rgb(0x7223D8))
        case .violet: Palette(background: rgb(0x7223D8), body: rgb(0xF4A3C0))
        case nil: Palette(background: rgb(0xE4E1EA), body: rgb(0xB7B2C0), head: rgb(0xCFCAD6))
        }
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// The profile picture: a photo (just picked or already uploaded) or a built-in avatar.
struct ProfilePictureView: View {
    let picture: ProfilePicture?
    /// A photo picked in the editor but not uploaded yet.
    var pickedPhoto: UIImage?
    var size: CGFloat = 50

    var body: some View {
        Group {
            if let pickedPhoto {
                Image(uiImage: pickedPhoto).resizable().scaledToFill()
            } else if case .photo(let url) = picture {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProfileAvatarView(avatar: nil, size: size).overlay { ProgressView() }
                }
            } else if case .avatar(let avatar) = picture {
                ProfileAvatarView(avatar: avatar, size: size)
            } else {
                ProfileAvatarView(avatar: nil, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
