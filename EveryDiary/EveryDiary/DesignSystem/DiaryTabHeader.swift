import SwiftUI

/// The title and settings button at the top of a tab. Every tab uses it, so they sit in the same place.
/// The caller adds the screen's horizontal padding and scrolls it with the content.
struct DiaryTabHeader: View {
    let title: String
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(DiaryTheme.Fonts.tabTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: DiaryTheme.Size.icon, weight: .semibold))
                    .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
            }
            // The icon's edge, not its touch area, lines up with the content edge.
            .padding(.trailing, -(DiaryTheme.Size.touchTarget - DiaryTheme.Size.icon) / 2)
            .accessibilityLabel("설정")
        }
        .foregroundStyle(DiaryTheme.Colors.brand)
        .padding(.top, DiaryTheme.TabHeader.top)
    }
}

extension View {
    /// Content scrolled up passes under the status bar; this keeps the clock readable over the screen's background.
    func diaryStatusBarBackground() -> some View {
        overlay(alignment: .top) {
            GeometryReader { geometry in
                DiaryTheme.Colors.background
                    .frame(height: geometry.safeAreaInsets.top)
                    .offset(y: -geometry.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
        }
    }
}
