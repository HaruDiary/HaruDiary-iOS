import SwiftUI

/// Plays a completed picture's moving details (falling snow, rising lanterns, fireworks …).
/// Every particle follows a fixed path from its index, so nothing is stored between frames.
struct JourneySceneAmbienceView: View {
    let ambience: [SceneAmbience]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let renderer = JourneySceneRenderer(size: size)
                let time = timeline.date.timeIntervalSinceReferenceDate
                for (layer, item) in ambience.enumerated() {
                    for index in 0..<item.count {
                        draw(item, index: index, seed: layer * 1000 + index, time: time, renderer: renderer, in: &context)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ item: SceneAmbience, index: Int, seed: Int, time: TimeInterval, renderer: JourneySceneRenderer, in context: inout GraphicsContext) {
        let area = item.area
        let n1 = noise(seed, 1), n2 = noise(seed, 2), n3 = noise(seed, 3), n4 = noise(seed, 4)
        let t = CGFloat(time.truncatingRemainder(dividingBy: 3600))
        let size = item.size.lowerBound + n3 * (item.size.upperBound - item.size.lowerBound)
        let color = item.colors[index % item.colors.count]
        var layer = context

        switch item.motion {
        case .fall, .rise:
            let travel = fraction(n2 + t * item.speed / area.height)
            let y = item.motion == .fall ? area.minY + travel * area.height : area.maxY - travel * area.height
            let x = area.minX + n1 * area.width + sin(t * (0.8 + n3) + n4 * 6) * (item.motion == .fall ? 14 : 6)
            // Fade in and out at the ends of the path.
            layer.opacity = Double(min(1, sin(travel * .pi) * 3))
            drawParticle(item.particle, at: CGPoint(x: x, y: y), size: size, rotation: t * (0.6 + n3) + n4 * 6, time: t, seed: seed,
                         color: color, glow: item.glow, renderer: renderer, in: &layer)
        case .wander:
            let x = area.minX + n1 * area.width + sin(t * (0.5 + n3) + n4 * 6) * 26
            let y = area.minY + n2 * area.height + cos(t * (0.4 + n3 * 0.5) + n4 * 5) * 18
            layer.opacity = item.particle == .butterfly ? 1 : Double(0.35 + 0.65 * abs(sin(t * (1 + n3) + n4 * 6)))
            drawParticle(item.particle, at: CGPoint(x: x, y: y), size: size, rotation: 0, time: t, seed: seed,
                         color: color, glow: item.glow, renderer: renderer, in: &layer)
        case .twinkle:
            let point = CGPoint(x: area.minX + n1 * area.width, y: area.minY + n2 * area.height)
            let pulse = pow(abs(sin(t * (0.8 + n3) + n4 * 6)), 2)
            layer.opacity = Double(0.15 + 0.85 * pulse)
            drawParticle(item.particle, at: point, size: size * (0.7 + 0.3 * pulse), rotation: 0, time: t, seed: seed,
                         color: color, glow: item.glow, renderer: renderer, in: &layer)
        case .burst:
            let period: CGFloat = 2.6
            let clock = t + CGFloat(index) * period / CGFloat(max(item.count, 1))
            let cycle = Int(clock / period)
            let progress = fraction(clock / period)
            let center = CGPoint(x: area.minX + noise(seed * 31 + cycle, 5) * area.width, y: area.minY + noise(seed * 31 + cycle, 6) * area.height)
            let radius = size * (1 - pow(1 - progress, 3))
            layer.opacity = Double(1 - progress)
            let rays = ScenePath.group((0..<14).map { ray -> CGPath in
                let angle = CGFloat(ray) * 2 * .pi / 14
                return ScenePath.line([(center.x + cos(angle) * radius * 0.4, center.y + sin(angle) * radius * 0.4),
                                       (center.x + cos(angle) * radius, center.y + sin(angle) * radius + progress * 10)])
            })
            renderer.draw(rays, color: item.colors[(index + cycle) % item.colors.count], lineWidth: 1.8, glow: item.glow, in: &layer)
        case .shootingStar:
            let period: CGFloat = 5.5
            let clock = t + CGFloat(index) * 2.7
            let cycle = Int(clock / period)
            let progress = fraction(clock / period)
            guard progress < 0.2 else { return }
            let q = progress / 0.2
            let start = CGPoint(x: area.minX + (0.5 + noise(seed * 17 + cycle, 7) * 0.5) * area.width, y: area.minY + noise(seed * 17 + cycle, 8) * area.height)
            let direction = CGPoint(x: -0.9, y: 0.44)
            let head = CGPoint(x: start.x + direction.x * q * 170, y: start.y + direction.y * q * 170)
            let tail = CGPoint(x: head.x - direction.x * 70, y: head.y - direction.y * 70)
            layer.opacity = Double(1 - q)
            renderer.draw(ScenePath.polygon([(head.x, head.y - 1.2), (tail.x, tail.y), (head.x, head.y + 1.2)]), color: color, lineWidth: nil, glow: 6, in: &layer)
            renderer.draw(ScenePath.circle(head.x, head.y, 1.8), color: color, lineWidth: nil, glow: 6, in: &layer)
        }
    }

    private func drawParticle(_ particle: SceneAmbience.Particle, at point: CGPoint, size: CGFloat, rotation: CGFloat, time: CGFloat, seed: Int,
                              color: SceneColor, glow: CGFloat, renderer: JourneySceneRenderer, in context: inout GraphicsContext) {
        let path: CGPath
        switch particle {
        case .dot:
            path = ScenePath.circle(point.x, point.y, size)
        case .snowflake:
            path = ScenePath.star(point.x, point.y, outer: size, inner: size * 0.4, points: 6, rotation: rotation)
        case .petal:
            path = ScenePath.ellipse(center: point, width: size * 1.2, height: size * 0.75, angle: rotation)
        case .mapleLeaf:
            path = ScenePath.outline(ScenePath.mapleLeaf, point.x, point.y, size: size, rotation: rotation)
        case .sparkle:
            path = ScenePath.star(point.x, point.y, outer: size, inner: size * 0.28, points: 4)
        case .lantern:
            let s = size
            path = ScenePath.polygon([(point.x - 5 * s, point.y - 9 * s), (point.x + 5 * s, point.y - 9 * s), (point.x + 7 * s, point.y + 9 * s), (point.x - 7 * s, point.y + 9 * s)])
        case .butterfly:
            // Wings open and close.
            let flap = 0.35 + 0.65 * abs(sin(time * 9 + CGFloat(seed)))
            path = ScenePath.group([
                ScenePath.ellipse(center: CGPoint(x: point.x - 5 * flap, y: point.y - 3), width: 10 * flap, height: 8, angle: -0.5),
                ScenePath.ellipse(center: CGPoint(x: point.x + 5 * flap, y: point.y - 3), width: 10 * flap, height: 8, angle: 0.5),
                ScenePath.ellipse(center: CGPoint(x: point.x - 4 * flap, y: point.y + 4), width: 6 * flap, height: 5, angle: 0.4),
                ScenePath.ellipse(center: CGPoint(x: point.x + 4 * flap, y: point.y + 4), width: 6 * flap, height: 5, angle: -0.4)
            ])
        case .firework:
            path = ScenePath.circle(point.x, point.y, size)
        }
        renderer.draw(path, color: color, lineWidth: nil, glow: glow, in: &context)
    }

    private func fraction(_ value: CGFloat) -> CGFloat {
        value - floor(value)
    }

    /// A stable number in 0..<1 for a particle and channel.
    private func noise(_ seed: Int, _ channel: Int) -> CGFloat {
        let value = sin(CGFloat(seed) * 12.9898 + CGFloat(channel) * 78.233) * 43758.5453
        return value - floor(value)
    }
}
