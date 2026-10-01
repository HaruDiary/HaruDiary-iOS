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
/// tapped or when the content scrolls up. A touch on the shrunk bar only grows it, so no tab opens by accident;
/// with VoiceOver the tabs are always selectable.
struct DiaryTabBar: View {
    let state: DiaryTabBarState
    let onSelect: (Int) -> Void
    let onExpand: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let expandedHeight: CGFloat = 60
    static let collapsedHeight: CGFloat = 44
    /// The bar is only as wide as its icons need, not stretched across the screen.
    static let expandedTabWidth: CGFloat = 68
    static let collapsedTabWidth: CGFloat = 46
    static let edgePadding: CGFloat = 6

    static func width(tabs: Int, collapsed: Bool) -> CGFloat {
        CGFloat(tabs) * (collapsed ? collapsedTabWidth : expandedTabWidth) + edgePadding * 2
    }

    var body: some View {
        GeometryReader { geometry in
            let collapsed = state.isCollapsed
            HStack(spacing: 0) {
                ForEach(state.tabs) { tab in
                    button(for: tab, collapsed: collapsed)
                }
            }
            .padding(.horizontal, Self.edgePadding)
            .frame(width: min(Self.width(tabs: state.tabs.count, collapsed: collapsed), geometry.size.width),
                   height: collapsed ? Self.collapsedHeight : Self.expandedHeight)
            .background { background }
            .overlay {
                // While shrunk a touch anywhere on the bar only grows it back.
                // VoiceOver skips this step: the shrinking is only visual, so the tabs stay directly selectable
                // (selecting one also grows the bar).
                if collapsed {
                    Color.clear
                        .contentShape(Capsule())
                        .onTapGesture(perform: onExpand)
                        .accessibilityHidden(true)
                }
            }
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
                            .padding(.vertical, collapsed ? 5 : 7)
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
            // The system's Liquid Glass, which bends and tints with whatever scrolls behind it.
            Color.clear.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay { Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
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
