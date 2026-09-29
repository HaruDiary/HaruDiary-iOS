import CoreGraphics
import Foundation

/// A month's picture on the journey tab. Each diary day lights one of `lights`, in order, until the month is full.
/// Drawn in a fixed design canvas and scaled to the view width, anchored to the bottom.
struct JourneyScene {
    static let canvas = CGSize(width: 390, height: 700)

    let month: Int
    let title: String
    /// Sky colors from top to bottom; they fill the whole view.
    let sky: [SceneColor]
    let background: [SceneElement]
    /// One slot per possible day of the month (29 for February). Only the first `numberOfDays` are shown.
    let lights: [SceneLight]
    let foreground: [SceneElement]
    /// Added to the picture once every day of the month is filled.
    let completion: [SceneElement]
    /// Moving details shown over a completed picture.
    let ambience: [SceneAmbience]
    /// The last light (such as the star on top of the tree) stays the last one to turn on.
    let keepsLastLightLast: Bool

    init(month: Int, title: String, sky: [SceneColor], background: [SceneElement], lights: [SceneLight],
         foreground: [SceneElement] = [], completion: [SceneElement] = [], ambience: [SceneAmbience] = [], keepsLastLightLast: Bool = false) {
        self.month = month
        self.title = title
        self.sky = sky
        self.background = background
        self.lights = lights
        self.foreground = foreground
        self.completion = completion
        self.ambience = ambience
        self.keepsLastLightLast = keepsLastLightLast
    }

    /// The slot each diary day lights, in order: the n-th day written lights `order[n - 1]`.
    /// A shuffle that stays the same for a given month and year, so a light never moves once it is on.
    func lightingOrder(slotCount: Int, year: Int) -> [Int] {
        let count = min(max(slotCount, 0), lights.count)
        var slots = Array(0..<count)
        let pinned = keepsLastLightLast && count == lights.count ? slots.popLast() : nil
        var random = SceneRandom(seed: UInt64(max(year, 0) * 100 + month) &* 2_654_435_761)
        if slots.count > 1 {
            for index in stride(from: slots.count - 1, to: 0, by: -1) {
                slots.swapAt(index, min(Int(random.next() * CGFloat(index + 1)), index))
            }
        }
        if let pinned { slots.append(pinned) }
        return slots
    }
}

/// A moving layer over a completed picture, such as falling snow or rising lanterns. Positions use the design canvas.
struct SceneAmbience {
    enum Motion {
        /// `drift` moves across `area` and wraps around (a negative speed goes right to left);
        /// `rotate` turns the particle at the center of `area` by `speed` radians per second.
        case fall, rise, wander, twinkle, burst, shootingStar, drift, rotate
    }

    enum Particle {
        case dot, snowflake, petal, mapleLeaf, sparkle, lantern, butterfly, bird, firework, cloud, car, ferrisWheel
    }

    let motion: Motion
    let particle: Particle
    let colors: [SceneColor]
    let count: Int
    let area: CGRect
    let size: ClosedRange<CGFloat>
    /// Points per second for moving particles.
    let speed: CGFloat
    let glow: CGFloat

    init(_ motion: Motion, _ particle: Particle, colors: [SceneColor], count: Int, area: CGRect,
         size: ClosedRange<CGFloat>, speed: CGFloat = 20, glow: CGFloat = 0) {
        self.motion = motion
        self.particle = particle
        self.colors = colors
        self.count = count
        self.area = area
        self.size = size
        self.speed = speed
        self.glow = glow
    }
}

struct SceneColor: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(_ hex: UInt32, opacity: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.opacity = opacity
    }

    init(red: Double, green: Double, blue: Double, opacity: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    func withOpacity(_ opacity: Double) -> SceneColor {
        SceneColor(red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct SceneElement {
    let path: CGPath
    let color: SceneColor
    /// nil fills the path; a width strokes it.
    let lineWidth: CGFloat?
    let glow: CGFloat
    /// A still stand-in for the ambience (settled snow, a frozen shooting star …).
    /// Shown in still pictures and faded out while the ambience plays.
    let isStill: Bool

    init(_ path: CGPath, _ color: SceneColor, lineWidth: CGFloat? = nil, glow: CGFloat = 0, still: Bool = false) {
        self.path = path
        self.color = color
        self.lineWidth = lineWidth
        self.glow = glow
        isStill = still
    }
}

struct SceneLight {
    let path: CGPath
    /// Shape while the day is still empty; nil draws `path` in `offColor`.
    let offPath: CGPath?
    let onColor: SceneColor
    let offColor: SceneColor
    let glow: CGFloat
    let lineWidth: CGFloat?
    /// Details drawn over the light only while it is on, such as a flower's center or a window frame.
    let accents: [SceneElement]

    init(_ path: CGPath, on: SceneColor, off: SceneColor, offPath: CGPath? = nil, glow: CGFloat = 0, lineWidth: CGFloat? = nil,
         accents: [SceneElement] = []) {
        self.path = path
        self.offPath = offPath
        onColor = on
        offColor = off
        self.glow = glow
        self.lineWidth = lineWidth
        self.accents = accents
    }
}

// MARK: - Shape helpers used by the catalog

enum ScenePath {
    static func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, corner: CGFloat = 0) -> CGPath {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        return corner > 0 ? CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil) : CGPath(rect: rect, transform: nil)
    }

    static func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2), transform: nil)
    }

    static func ellipse(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x, y: y, width: width, height: height), transform: nil)
    }

    static func ellipse(center: CGPoint, width: CGFloat, height: CGFloat, angle: CGFloat) -> CGPath {
        var transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
        return CGPath(ellipseIn: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), transform: &transform)
    }

    static func polygon(_ points: [(CGFloat, CGFloat)]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }

    static func line(_ points: [(CGFloat, CGFloat)]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
        return path
    }

    static func curve(from start: CGPoint, to end: CGPoint, control: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }

    static func arc(_ x: CGFloat, _ y: CGFloat, radius: CGFloat, from start: CGFloat, to end: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addArc(center: CGPoint(x: x, y: y), radius: radius, startAngle: start, endAngle: end, clockwise: false)
        return path
    }

    /// A star with `points` tips.
    static func star(_ x: CGFloat, _ y: CGFloat, outer: CGFloat, inner: CGFloat, points: Int, rotation: CGFloat = -.pi / 2) -> CGPath {
        let corners = (0..<(points * 2)).map { index -> (CGFloat, CGFloat) in
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = rotation + CGFloat(index) * .pi / CGFloat(points)
            return (x + cos(angle) * radius, y + sin(angle) * radius)
        }
        return polygon(corners)
    }

    /// A pointed petal or leaf from `base` toward `angle`.
    static func petal(from base: CGPoint, length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        let tip = CGPoint(x: base.x + direction.x * length, y: base.y + direction.y * length)
        let middle = CGPoint(x: base.x + direction.x * length * 0.5, y: base.y + direction.y * length * 0.5)
        let path = CGMutablePath()
        path.move(to: base)
        path.addQuadCurve(to: tip, control: CGPoint(x: middle.x + normal.x * width, y: middle.y + normal.y * width))
        path.addQuadCurve(to: base, control: CGPoint(x: middle.x - normal.x * width, y: middle.y - normal.y * width))
        path.closeSubpath()
        return path
    }

    /// A five-petal cherry blossom.
    static func blossom(_ x: CGFloat, _ y: CGFloat, radius: CGFloat, rotation: CGFloat = 0) -> CGPath {
        group((0..<5).map { index in
            let angle = rotation - .pi / 2 + CGFloat(index) * 2 * .pi / 5
            let center = CGPoint(x: x + cos(angle) * radius * 0.52, y: y + sin(angle) * radius * 0.52)
            return ellipse(center: center, width: radius * 0.98, height: radius * 0.78, angle: angle)
        })
    }

    /// A polygon given in unit coordinates (about -1...1), placed at `x, y`.
    static func outline(_ points: [(CGFloat, CGFloat)], _ x: CGFloat, _ y: CGFloat, size: CGFloat, rotation: CGFloat = 0) -> CGPath {
        polygon(points.map { px, py in
            (x + (px * cos(rotation) - py * sin(rotation)) * size, y + (px * sin(rotation) + py * cos(rotation)) * size)
        })
    }

    static let mapleLeaf: [(CGFloat, CGFloat)] = {
        let right: [(CGFloat, CGFloat)] = [(0.14, -0.62), (0.42, -0.8), (0.33, -0.4), (0.78, -0.52), (0.6, -0.18), (0.98, -0.06),
                                           (0.62, 0.12), (0.72, 0.4), (0.3, 0.26), (0.06, 0.45)]
        return [(0, -1)] + right + right.reversed().map { (-$0.0, $0.1) }
    }()

    /// A soft curved band across the sky, for auroras and the Milky Way.
    static func band(from start: CGPoint, to end: CGPoint, bend: CGFloat, thickness: CGFloat) -> CGPath {
        let control = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 + bend)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        path.addLine(to: CGPoint(x: end.x, y: end.y + thickness))
        path.addQuadCurve(to: CGPoint(x: start.x, y: start.y + thickness), control: CGPoint(x: control.x, y: control.y + thickness * 1.6))
        path.closeSubpath()
        return path
    }

    /// Several shapes drawn as one.
    static func group(_ paths: [CGPath]) -> CGPath {
        let path = CGMutablePath()
        paths.forEach { path.addPath($0) }
        return path
    }

    static func point(onCurveFrom start: CGPoint, to end: CGPoint, control: CGPoint, at t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                       y: u * u * start.y + 2 * u * t * control.y + t * t * end.y)
    }
}

/// Deterministic numbers so a scene looks the same on every launch and device.
struct SceneRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }

    mutating func next(_ range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + next() * (range.upperBound - range.lowerBound)
    }
}
