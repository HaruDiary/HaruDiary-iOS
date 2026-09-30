import Observation
import SwiftUI

struct DiaryTab: Identifiable, Equatable {
    let id: Int
    let title: String
    /// A template image in the asset catalog.
    let image: String
}

@MainActor
@Observable
final class DiaryTabBarState {
    let tabs: [DiaryTab]
    var selected = 0
    var isCollapsed = false
    var isHidden = false

    init(tabs: [DiaryTab]) {
        self.tabs = tabs
    }
}

/// A floating pill of icons, like Instagram's: it shrinks while the content scrolls down and grows back when
/// tapped or when the content scrolls up. A tap on the shrunk bar only grows it, so no tab opens by accident.
struct DiaryTabBar: View {
    let state: DiaryTabBarState
    let onSelect: (Int) -> Void
    let onExpand: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let expandedHeight: CGFloat = 62
    static let collapsedHeight: CGFloat = 46
    static let maxWidth: CGFloat = 360

    var body: some View {
        GeometryReader { geometry in
            let full = min(geometry.size.width, Self.maxWidth)
            let collapsed = state.isCollapsed
            HStack(spacing: 0) {
                ForEach(state.tabs) { tab in
                    button(for: tab, collapsed: collapsed)
                }
            }
            .padding(.horizontal, collapsed ? 6 : 8)
            .frame(width: collapsed ? full * 0.62 : full, height: collapsed ? Self.collapsedHeight : Self.expandedHeight)
            .background { background }
            .overlay {
                // While shrunk the whole bar is one target that grows it back.
                if collapsed {
                    Color.clear
                        .contentShape(Capsule())
                        .onTapGesture(perform: onExpand)
                        .accessibilityElement()
                        .accessibilityLabel("탭 막대 펼치기")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .offset(y: state.isHidden ? Self.expandedHeight * 2 : 0)
            .opacity(state.isHidden ? 0 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.82),
                       value: collapsed)
            .animation(.easeOut(duration: 0.25), value: state.isHidden)
        }
    }

    private func button(for tab: DiaryTab, collapsed: Bool) -> some View {
        let isSelected = tab.id == state.selected
        return Button { onSelect(tab.id) } label: {
            Image(tab.image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: collapsed ? 20 : 26, height: collapsed ? 20 : 26)
                .foregroundStyle(isSelected ? DiaryTheme.Colors.brand : DiaryTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(DiaryTheme.Colors.brand.opacity(0.12))
                            .padding(.vertical, collapsed ? 5 : 8)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(TabPressStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var background: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5) }
        }
    }
}

/// A light press-down, like Instagram's icons.
private struct TabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
