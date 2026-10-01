import SwiftUI

/// The title and settings button at the top of a tab. Every tab uses it, so they sit in the same place.
/// The caller adds the screen's horizontal padding and scrolls it with the content.
struct DiaryTabHeader: View {
    /// A second button left of settings, in the same style (the journey tab's collection).
    struct Extra {
        let systemImage: String
        let label: String
        let action: () -> Void
    }

    let title: String
    /// White over the journey tab's picture.
    var tint: Color = DiaryTheme.Colors.brand
    var extra: Extra? = nil
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(DiaryTheme.Fonts.tabTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let extra {
                button(systemImage: extra.systemImage, label: extra.label, action: extra.action)
            }
            button(systemImage: "gearshape", label: "설정", action: onOpenSettings)
                // The icon's edge, not its touch area, lines up with the content edge.
                .padding(.trailing, -(DiaryTheme.Size.touchTarget - DiaryTheme.Size.icon) / 2)
        }
        .foregroundStyle(tint)
        .padding(.top, DiaryTheme.TabHeader.top)
    }

    private func button(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: DiaryTheme.Size.icon, weight: .semibold))
                .frame(width: DiaryTheme.Size.touchTarget, height: DiaryTheme.Size.touchTarget)
        }
        .accessibilityLabel(label)
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
