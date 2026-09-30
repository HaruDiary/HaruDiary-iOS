import SwiftUI

/// Where a photo is still loading: a soft block with a light passing over it, instead of a spinner.
/// The photo then fades in over it (`PhotoSkeleton.fadeIn`), so it never pops in.
struct PhotoSkeleton: View {
    var cornerRadius: CGFloat = DiaryTheme.Radius.card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var sweep = false

    static let fadeIn = Animation.easeOut(duration: 0.3)

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DiaryTheme.Colors.selection.opacity(colorScheme == .dark ? 0.25 : 0.45))
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        LinearGradient(colors: [.clear, highlight, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: width * 0.7)
                            .offset(x: sweep ? width : -width * 0.7)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) { sweep = true }
            }
            .accessibilityLabel("사진을 불러오는 중")
    }

    private var highlight: Color {
        .white.opacity(colorScheme == .dark ? 0.12 : 0.55)
    }
}

#if DEBUG
#Preview("사진 자리") {
    HStack {
        PhotoSkeleton().frame(width: 96, height: 96)
        PhotoSkeleton(cornerRadius: 8).frame(width: 64, height: 64)
    }
    .padding()
}
#endif
