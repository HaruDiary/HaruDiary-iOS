import CoreGraphics
import Foundation

/// Landscape pieces the monthly pictures share: ridges, stars, the moon, trees, clouds, grass, water and hanok roofs.
/// Every piece is seeded, so a picture looks the same on every launch and device. Coordinates use `JourneyScene.canvas`.
enum SceneArt {
    // MARK: Land

    /// A rough mountain ridge from `left` to `right`, filled down to `bottom`. `height` is how far peaks rise above `baseline`.
    static func ridge(seed: UInt64, baseline: CGFloat, height: CGFloat, roughness: CGFloat = 0.55, detail: Int = 6,
                      left: CGFloat = -10, right: CGFloat = 400, bottom: CGFloat = 700) -> CGPath {
        var random = SceneRandom(seed: seed)
        var values: [CGFloat] = [random.next(0.2...0.7), random.next(0.2...0.7)]
        var spread: CGFloat = 0.5
        for _ in 0..<detail {
            var next: [CGFloat] = []
            for index in 0..<(values.count - 1) {
                next.append(values[index])
                next.append((values[index] + values[index + 1]) / 2 + random.next(-spread...spread))
            }
            next.append(values[values.count - 1])
            values = next
            spread *= roughness
        }
        // Stretched so the lowest point sits on the baseline and the highest peak reaches the full height.
        let low = values.min() ?? 0, high = values.max() ?? 1
        values = values.map { ($0 - low) / max(high - low, 0.001) }
        let step = (right - left) / CGFloat(values.count - 1)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: left, y: bottom))
        for (index, value) in values.enumerated() {
            path.addLine(to: CGPoint(x: left + CGFloat(index) * step, y: baseline - value * height))
        }
        path.addLine(to: CGPoint(x: right, y: bottom))
        path.closeSubpath()
        return path
    }

    /// A smooth line of hills through `tops`, filled down to `bottom`.
    static func hills(_ tops: [(CGFloat, CGFloat)], bottom: CGFloat = 700) -> CGPath {
        let points = tops.map { CGPoint(x: $0.0, y: $0.1) }
        let path = CGMutablePath()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: first.x, y: bottom))
        path.addLine(to: first)
        for index in 1..<points.count {
            let previous = points[index - 1], point = points[index]
            let middle = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
            path.addQuadCurve(to: middle, control: previous)
            if index == points.count - 1 { path.addQuadCurve(to: point, control: point) }
        }
        path.addLine(to: CGPoint(x: last.x, y: bottom))
        path.closeSubpath()
        return path
    }

    /// Blades of grass along `baseline`, each leaning a little.
    static func grass(seed: UInt64, count: Int, x: ClosedRange<CGFloat>, baseline: CGFloat, height: ClosedRange<CGFloat>, width: CGFloat = 2.4) -> CGPath {
        var random = SceneRandom(seed: seed)
        return ScenePath.group((0..<count).map { _ in
            let root = random.next(x), tall = random.next(height), lean = random.next(-0.45...0.45) * tall
            let base = baseline + random.next(0...4)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: root - width / 2, y: base))
            path.addQuadCurve(to: CGPoint(x: root + lean, y: base - tall), control: CGPoint(x: root - width / 2 + lean * 0.2, y: base - tall * 0.6))
            path.addQuadCurve(to: CGPoint(x: root + width / 2, y: base), control: CGPoint(x: root + width / 2 + lean * 0.3, y: base - tall * 0.5))
            path.closeSubpath()
            return path
        })
    }

    // MARK: Sky

    /// Stars in three brightnesses: a dim field, a middle layer, and a few bright ones with a cross of light.
    static func stars(seed: UInt64, count: Int, area: CGRect, color: SceneColor = SceneColor(0xFFFFFF),
                      avoiding: (CGPoint) -> Bool = { _ in false }, still: Bool = false) -> [SceneElement] {
        var random = SceneRandom(seed: seed)
        var dim: [CGPath] = [], middle: [CGPath] = [], bright: [CGPath] = [], rays: [CGPath] = []
        for index in 0..<count {
            let point = CGPoint(x: random.next(area.minX...area.maxX), y: area.minY + pow(random.next(), 1.4) * area.height)
            guard !avoiding(point) else { continue }
            switch index % 12 {
            case 0:
                bright.append(ScenePath.circle(point.x, point.y, random.next(1.3...1.8)))
                let length = random.next(4...7)
                rays.append(ScenePath.line([(point.x - length, point.y), (point.x + length, point.y)]))
                rays.append(ScenePath.line([(point.x, point.y - length), (point.x, point.y + length)]))
            case 1...4: middle.append(ScenePath.circle(point.x, point.y, random.next(0.8...1.2)))
            default: dim.append(ScenePath.circle(point.x, point.y, random.next(0.4...0.8)))
            }
        }
        return [
            SceneElement(ScenePath.group(dim), color.withOpacity(0.45), still: still),
            SceneElement(ScenePath.group(middle), color.withOpacity(0.75), still: still),
            SceneElement(ScenePath.group(rays), color.withOpacity(0.5), lineWidth: 0.6, still: still),
            SceneElement(ScenePath.group(bright), color, glow: 3, still: still)
        ]
    }

    /// A moon with a soft halo, a shaded disk and faint seas.
    static func moon(_ x: CGFloat, _ y: CGFloat, radius: CGFloat, light: SceneColor = SceneColor(0xFFF6DC),
                     shade: SceneColor = SceneColor(0xEFD9A6), halo: SceneColor? = nil, seas: Bool = true) -> [SceneElement] {
        let haloColor = halo ?? light
        var elements = [
            SceneElement(ScenePath.circle(x, y, radius * 2.6), haloColor.withOpacity(0.08), blur: radius * 0.8),
            SceneElement(ScenePath.circle(x, y, radius * 1.5), haloColor.withOpacity(0.16), blur: radius * 0.35),
            SceneElement(ScenePath.circle(x, y, radius), gradient: [light, shade], glow: radius * 0.45)
        ]
        if seas {
            let spots = ScenePath.group([
                ScenePath.ellipse(center: CGPoint(x: x - radius * 0.3, y: y - radius * 0.2), width: radius * 0.55, height: radius * 0.4, angle: 0.4),
                ScenePath.ellipse(center: CGPoint(x: x + radius * 0.28, y: y + radius * 0.3), width: radius * 0.45, height: radius * 0.32, angle: -0.3),
                ScenePath.circle(x + radius * 0.35, y - radius * 0.38, radius * 0.12),
                ScenePath.circle(x - radius * 0.15, y + radius * 0.5, radius * 0.1)
            ])
            elements.append(SceneElement(spots, shade.withOpacity(0.55)))
        }
        return elements
    }

    /// A puffy cloud with a flat base, `width` wide, its base at `y`.
    static func cloud(_ x: CGFloat, _ y: CGFloat, width: CGFloat) -> CGPath {
        let unit = width / 10
        return ScenePath.group([
            ScenePath.ellipse(x, y - unit * 2.2, width, unit * 2.4),
            ScenePath.circle(x + unit * 2.6, y - unit * 2.4, unit * 1.9),
            ScenePath.circle(x + unit * 4.9, y - unit * 3.3, unit * 2.7),
            ScenePath.circle(x + unit * 7.3, y - unit * 2.5, unit * 2)
        ])
    }

    // MARK: Trees

    /// A pine with drooping tiers, from `base` up `height`, `width` across at the bottom.
    static func pine(_ x: CGFloat, base: CGFloat, height: CGFloat, width: CGFloat, tiers: Int = 5) -> CGPath {
        let crownBottom = base - height * 0.08
        let tip = base - height
        var left: [(CGFloat, CGFloat)] = [], right: [(CGFloat, CGFloat)] = []
        for tier in 1...tiers {
            let fraction = CGFloat(tier) / CGFloat(tiers)
            let y = tip + (crownBottom - tip) * fraction
            let half = width / 2 * (0.25 + 0.75 * fraction)
            let tuck = half * 0.55
            right += [(x + half, y), (x + tuck, y - (crownBottom - tip) / CGFloat(tiers) * 0.3)]
            left += [(x - half, y), (x - tuck, y - (crownBottom - tip) / CGFloat(tiers) * 0.3)]
        }
        right.removeLast()
        left.removeLast()
        let crown = ScenePath.polygon([(x, tip)] + right + [(x + width * 0.06, crownBottom), (x - width * 0.06, crownBottom)] + left.reversed())
        return ScenePath.group([crown, ScenePath.rect(x - width * 0.05, crownBottom - 2, width * 0.1, base - crownBottom + 2)])
    }

    /// A line of pines across `x`, sizes and spacing varying with the seed.
    static func pines(seed: UInt64, x: ClosedRange<CGFloat>, base: CGFloat, height: ClosedRange<CGFloat>, spacing: CGFloat, widthRatio: CGFloat = 0.42) -> CGPath {
        var random = SceneRandom(seed: seed)
        var trees: [CGPath] = []
        var position = x.lowerBound
        while position <= x.upperBound {
            let tall = random.next(height)
            trees.append(pine(position, base: base + random.next(-4...4), height: tall, width: tall * widthRatio * random.next(0.85...1.15)))
            position += spacing * random.next(0.7...1.3)
        }
        return ScenePath.group(trees)
    }

    /// A round leafy crown made of overlapping puffs, centered at `x, y`.
    static func crown(seed: UInt64, _ x: CGFloat, _ y: CGFloat, radius: CGFloat, puffs: Int = 7) -> CGPath {
        var random = SceneRandom(seed: seed)
        return ScenePath.group([ScenePath.circle(x, y, radius * 0.75)] + (0..<puffs).map { index in
            let angle = CGFloat(index) / CGFloat(puffs) * 2 * .pi + random.next(-0.3...0.3)
            let distance = radius * random.next(0.45...0.6)
            return ScenePath.circle(x + cos(angle) * distance, y + sin(angle) * distance * 0.8, radius * random.next(0.42...0.55))
        })
    }

    /// A trunk that splits into curving branches toward `tips`, wide at the root and thin at the ends.
    static func trunk(root: CGPoint, fork: CGPoint, width: CGFloat, branches: [(tip: CGPoint, width: CGFloat)]) -> CGPath {
        func limb(from start: CGPoint, to end: CGPoint, startWidth: CGFloat, endWidth: CGFloat) -> CGPath {
            let angle = atan2(end.y - start.y, end.x - start.x)
            let normal = CGPoint(x: -sin(angle), y: cos(angle))
            let bend = CGPoint(x: (start.x + end.x) / 2 + normal.x * hypot(end.x - start.x, end.y - start.y) * 0.08,
                               y: (start.y + end.y) / 2 + normal.y * hypot(end.x - start.x, end.y - start.y) * 0.08)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: start.x + normal.x * startWidth / 2, y: start.y + normal.y * startWidth / 2))
            path.addQuadCurve(to: CGPoint(x: end.x + normal.x * endWidth / 2, y: end.y + normal.y * endWidth / 2), control: bend)
            path.addLine(to: CGPoint(x: end.x - normal.x * endWidth / 2, y: end.y - normal.y * endWidth / 2))
            path.addQuadCurve(to: CGPoint(x: start.x - normal.x * startWidth / 2, y: start.y - normal.y * startWidth / 2), control: bend)
            path.closeSubpath()
            return path
        }
        // The root flares out where it meets the ground.
        let flare = ScenePath.polygon([(root.x - width * 1.1, root.y), (root.x - width * 0.45, root.y - width * 0.9),
                                       (root.x + width * 0.45, root.y - width * 0.9), (root.x + width * 1.1, root.y)])
        return ScenePath.group([flare, limb(from: root, to: fork, startWidth: width, endWidth: width * 0.75)]
                               + branches.map { limb(from: fork, to: $0.tip, startWidth: width * 0.62, endWidth: $0.width) })
    }

    // MARK: Water

    /// Broken streaks of light on water under `x`, narrowing from `top` down to `bottom`.
    static func shimmer(seed: UInt64, x: CGFloat, top: CGFloat, bottom: CGFloat, width: CGFloat, rows: Int = 9) -> CGPath {
        var random = SceneRandom(seed: seed)
        return ScenePath.group((0..<rows).map { row in
            let fraction = CGFloat(row) / CGFloat(max(rows - 1, 1))
            let y = top + (bottom - top) * fraction
            let span = width * (1 - fraction * 0.55) * random.next(0.6...1)
            return ScenePath.rect(x - span / 2 + random.next(-6...6), y, span, 1.6 + fraction * 1.2, corner: 1)
        })
    }

    /// Thin wave lines across water, sparser toward the horizon.
    static func ripples(seed: UInt64, area: CGRect, count: Int) -> CGPath {
        var random = SceneRandom(seed: seed)
        return ScenePath.group((0..<count).map { _ in
            let y = area.minY + pow(random.next(), 0.7) * area.height
            let length = 6 + (y - area.minY) / area.height * 22 * random.next(0.6...1.2)
            let x = random.next(area.minX...area.maxX)
            return ScenePath.curve(from: CGPoint(x: x, y: y), to: CGPoint(x: x + length, y: y), control: CGPoint(x: x + length / 2, y: y - 1.6))
        })
    }

    // MARK: Hanok

    /// A tiled hanok roof whose eaves curve up at both ends. `y` is the eave line at the middle, `width` the eave span.
    static func hanokRoof(_ x: CGFloat, _ y: CGFloat, width: CGFloat, height: CGFloat, lift: CGFloat? = nil) -> (roof: CGPath, tiles: CGPath, ridge: CGPath) {
        let lift = lift ?? height * 0.45
        let left = CGPoint(x: x - width / 2, y: y - lift), right = CGPoint(x: x + width / 2, y: y - lift)
        let ridgeLeft = CGPoint(x: x - width * 0.3, y: y - height), ridgeRight = CGPoint(x: x + width * 0.3, y: y - height)
        let roof = CGMutablePath()
        roof.move(to: left)
        roof.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - width * 0.3, y: y + lift * 0.15))
        roof.addQuadCurve(to: right, control: CGPoint(x: x + width * 0.3, y: y + lift * 0.15))
        roof.addQuadCurve(to: ridgeRight, control: CGPoint(x: x + width * 0.36, y: y - lift * 0.7))
        roof.addLine(to: ridgeLeft)
        roof.addQuadCurve(to: left, control: CGPoint(x: x - width * 0.36, y: y - lift * 0.7))
        roof.closeSubpath()
        let columns = max(Int(width / 7), 4)
        let tiles = ScenePath.group((1..<columns).map { column -> CGPath in
            let t = CGFloat(column) / CGFloat(columns)
            let top = CGPoint(x: ridgeLeft.x + (ridgeRight.x - ridgeLeft.x) * t, y: ridgeLeft.y + 2)
            let eave = ScenePath.point(onCurveFrom: left, to: right, control: CGPoint(x: x, y: y + lift * 1.1), at: t)
            return ScenePath.line([(top.x, top.y), (eave.x, eave.y - 1.5)])
        })
        let ridge = ScenePath.line([(ridgeLeft.x - 5, ridgeLeft.y - 3), (ridgeLeft.x, ridgeLeft.y), (ridgeRight.x, ridgeRight.y), (ridgeRight.x + 5, ridgeRight.y - 3)])
        return (roof, tiles, ridge)
    }
}
