import SwiftUI

/// How a tab's first screen works with the floating tab bar: its scrolling shrinks the bar, and tapping the
/// open tab again scrolls it back to the top. Nil in previews and for screens that are not a tab's first screen.
struct TabRoot {
    let shell: AppShell
    /// The tab this screen belongs to. Tabs opened before stay alive behind the open one and must not react.
    let tab: Int

    static let topID = "tab-root-top"
}

extension View {
    /// For the scroll view of a tab's first screen. `proxy` scrolls it; its content (or first row) carries `TabRoot.topID`.
    @ViewBuilder
    func tabRoot(_ tabRoot: TabRoot?, proxy: ScrollViewProxy) -> some View {
        if let tabRoot {
            let shell = tabRoot.shell
            shrinksTabBar(shell, tab: tabRoot.tab)
                .onChange(of: shell.scrollToTopCount) {
                    guard shell.tabBar.selected == tabRoot.tab else { return }
                    withAnimation { proxy.scrollTo(TabRoot.topID, anchor: .top) }
                }
        } else {
            self
        }
    }
}
