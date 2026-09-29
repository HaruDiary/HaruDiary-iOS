import SwiftUI
import UIKit

/// A plain person silhouette on a solid circle; members pick the color.
struct ProfileAvatarView: View {
    /// nil draws the signed-out/guest placeholder.
    let avatar: ProfileAvatar?
    var size: CGFloat = 50

    var body: some View {
        ZStack {
            Circle().fill(Self.color(for: avatar))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.5, weight: .regular))
                .foregroundStyle(.white)
                .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// For UIKit cells: the same drawing as an image.
    @MainActor
    static func image(for avatar: ProfileAvatar?, size: CGFloat, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: ProfileAvatarView(avatar: avatar, size: size))
        renderer.scale = scale
        return renderer.uiImage
    }

    private static func color(for avatar: ProfileAvatar?) -> Color {
        switch avatar {
        case .purple: rgb(0x21005D)
        case .violet: rgb(0x7223D8)
        case .lavender: rgb(0xA98BE0)
        case .green: rgb(0x5E8C6A)
        case .blue: rgb(0x5B7FA6)
        case .orange: rgb(0xD9825B)
        case .brown: rgb(0x8A6A57)
        case .pink: rgb(0xC0698A)
        case nil: rgb(0xB5B0BC)
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
                    ProfileAvatarView(avatar: .default, size: size).overlay { ProgressView().tint(.white) }
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
