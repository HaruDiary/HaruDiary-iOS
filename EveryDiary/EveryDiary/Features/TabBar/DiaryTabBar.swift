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

/// A floating pill of icons that behaves like Instagram's and the system's glass tab bar:
/// - A touch selects on release, so a tap opens its tab at once, also while the bar is shrunk.
/// - Pressing lifts the highlight; sliding moves it with the finger and letting go opens the tab under it.
/// - The highlight glides to the tab that was opened instead of jumping there.
/// - The bar shrinks while the content scrolls down and grows back when it scrolls up or a tab is opened.
struct DiaryTabBar: View {
    let state: DiaryTabBarState
    let onSelect: (Int) -> Void

    /// Where the finger is along the bar while it is pressed.
    @State private var touch: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let expandedHeight: CGFloat = 60
    static let collapsedHeight: CGFloat = 44
    /// The bar is only as wide as its icons need, not stretched across the screen.
    static let expandedTabWidth: CGFloat = 68
    static let collapsedTabWidth: CGFloat = 46
    static let edgePadding: CGFloat = 6
    /// Letting go this far above or below the bar opens nothing.
    static let cancelDistance: CGFloat = 60

    static func width(tabs: Int, collapsed: Bool) -> CGFloat {
        CGFloat(tabs) * (collapsed ? collapsedTabWidth : expandedTabWidth) + edgePadding * 2
    }

    /// The tab under a point of the bar; a point past either end counts as the nearest tab.
    static func tabIndex(at x: CGFloat, tabs: Int, collapsed: Bool) -> Int {
        guard tabs > 0 else { return 0 }
        let tabWidth = collapsed ? collapsedTabWidth : expandedTabWidth
        return min(max(Int(((x - edgePadding) / tabWidth).rounded(.down)), 0), tabs - 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let collapsed = state.isCollapsed
            let tabWidth = collapsed ? Self.collapsedTabWidth : Self.expandedTabWidth
            let height = collapsed ? Self.collapsedHeight : Self.expandedHeight
            let selectedIndex = state.tabs.firstIndex { $0.id == state.selected } ?? 0
            // While pressed, the tab under the finger is the one about to open.
            let aimed = touch.map { Self.tabIndex(at: $0, tabs: state.tabs.count, collapsed: collapsed) }
            let lensCenter = lensCenter(tabWidth: tabWidth, selectedIndex: selectedIndex)
            HStack(spacing: 0) {
                ForEach(Array(state.tabs.enumerated()), id: \.element.id) { index, tab in
                    icon(for: tab, isLit: index == (aimed ?? selectedIndex), isAimed: index == aimed, collapsed: collapsed)
                        .frame(width: tabWidth, height: height)
                }
            }
            .padding(.horizontal, Self.edgePadding)
            .background(alignment: .leading) {
                // The highlight: under the open tab, or under the finger while the bar is pressed.
                Capsule()
                    .fill(DiaryTheme.Colors.brand.opacity(touch == nil ? 0.12 : 0.2))
                    .frame(width: tabWidth, height: height - (collapsed ? 10 : 14))
                    .scaleEffect(touch == nil || reduceMotion ? 1 : 1.12)
                    .offset(x: lensCenter - tabWidth / 2)
            }
            .background { background }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in touch = drag.location.x }
                    .onEnded { drag in
                        touch = nil
                        guard abs(drag.location.y - height / 2) <= height / 2 + Self.cancelDistance else { return }
                        let index = Self.tabIndex(at: drag.location.x, tabs: state.tabs.count, collapsed: collapsed)
                        if state.tabs.indices.contains(index) { onSelect(state.tabs[index].id) }
                    }
            )
            // A tick each time the finger crosses onto another tab, and a light tap when a tab opens.
            .sensoryFeedback(trigger: aimed) { old, new in old != nil && new != nil ? .selection : nil }
            .sensoryFeedback(.impact(weight: .light), trigger: state.selected)
            .scaleEffect(touch == nil || reduceMotion ? 1 : 1.04)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .offset(y: state.isHidden ? Self.expandedHeight * 2 : 0)
            .opacity(state.isHidden ? 0 : 1)
            // Following the finger is immediate; settling on a tab is a short spring.
            .animation(touch == nil ? settle : .interactiveSpring(response: 0.16, dampingFraction: 0.8), value: lensCenter)
            .animation(settle, value: touch == nil)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.82),
                       value: collapsed)
            .animation(.easeOut(duration: 0.25), value: state.isHidden)
        }
    }

    private var settle: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.72)
    }

    /// The highlight's centre from the bar's leading edge: under the finger, kept inside the bar, or on the open tab.
    private func lensCenter(tabWidth: CGFloat, selectedIndex: Int) -> CGFloat {
        let first = Self.edgePadding + tabWidth / 2
        guard let touch else { return first + CGFloat(selectedIndex) * tabWidth }
        return min(max(touch, first), first + CGFloat(max(state.tabs.count - 1, 0)) * tabWidth)
    }

    private func icon(for tab: DiaryTab, isLit: Bool, isAimed: Bool, collapsed: Bool) -> some View {
        Image(tab.image)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: collapsed ? 20 : 26, height: collapsed ? 20 : 26)
            .foregroundStyle(isLit ? DiaryTheme.Colors.brand : DiaryTheme.Colors.secondaryText)
            .scaleEffect(isAimed && !reduceMotion ? 1.15 : 1)
            .animation(settle, value: isLit)
            .animation(settle, value: isAimed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // The bar is one touch surface; assistive technologies get each tab as its own button.
            .accessibilityElement()
            .accessibilityLabel(tab.title)
            .accessibilityAddTraits(tab.id == state.selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { onSelect(tab.id) }
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
