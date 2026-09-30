import CoreGraphics

/// When the floating tab bar shrinks, like Instagram's: scrolling down into the content shrinks it,
/// scrolling back up or reaching the top grows it. Small movements are ignored so it does not flicker.
struct TabBarCollapse: Equatable {
    /// Scrolling less than this in one direction does not change the bar.
    static let threshold: CGFloat = 12
    /// Near the top the bar is always full size.
    static let topZone: CGFloat = 24

    private(set) var isCollapsed = false
    private var anchor: CGFloat?

    /// `offset` is the distance scrolled from the top of the content (0 at the top).
    mutating func scrolled(to offset: CGFloat) {
        guard offset > Self.topZone else {
            isCollapsed = false
            anchor = offset
            return
        }
        guard let start = anchor else {
            anchor = offset
            return
        }
        let moved = offset - start
        if moved > Self.threshold {
            isCollapsed = true
            anchor = offset
        } else if moved < -Self.threshold {
            isCollapsed = false
            anchor = offset
        } else if (isCollapsed && moved > 0) || (!isCollapsed && moved < 0) {
            // Keep following the current direction so a turn is measured from where it turned.
            anchor = offset
        }
    }

    /// A tap on the shrunk bar, a tab change or a new screen shows the bar at full size.
    mutating func expand(at offset: CGFloat? = nil) {
        isCollapsed = false
        anchor = offset
    }
}
