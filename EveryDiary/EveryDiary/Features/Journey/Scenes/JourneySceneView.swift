import SwiftUI

/// Draws a month's picture with `litCount` lights on, out of `slotCount` (the days of that month).
/// Lights turn on in the month's shuffled order. With `animatesLighting`, they sweep on smoothly
/// and a completed picture gets its moving details; thumbnails stay still.
struct JourneySceneView: View {
    let scene: JourneyScene
    let year: Int
    let litCount: Int
    let slotCount: Int
    var animatesLighting = false

    /// Lights already shown before the current sweep.
    @State private var shownBeforeSweep: Double = 0
    @State private var sweepStart: Date?

    private static let sweepDuration: TimeInterval = 1.0

    private var visibleSlots: Int { min(max(slotCount, 0), scene.lights.count) }
    private var target: Int { min(max(litCount, 0), visibleSlots) }
    private var isComplete: Bool {
        visibleSlots > 0 && target >= visibleSlots && (!animatesLighting || (sweepStart == nil && shownBeforeSweep >= Double(target)))
    }

    private var isAmbiencePlaying: Bool { animatesLighting && isComplete && !scene.ambience.isEmpty }

    var body: some View {
        let order = scene.lightingOrder(slotCount: visibleSlots, year: year)
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        ZStack {
            TimelineView(.animation(paused: sweepStart == nil)) { timeline in
                Canvas { context, size in
                    let renderer = JourneySceneRenderer(size: size)
                    let shown = shownCount(at: timeline.date)
                    renderer.fillSky(scene.sky, in: &context)
                    scene.background.filter { !$0.isStill }.forEach { renderer.draw($0, in: &context) }
                    for (index, light) in scene.lights.prefix(visibleSlots).enumerated() {
                        // Each light fades in over the moment the sweep passes its turn.
                        let amount = min(max(shown - Double(rank[index] ?? index), 0), 1)
                        renderer.draw(light, amount: amount, in: &context)
                    }
                    scene.foreground.forEach { renderer.draw($0, in: &context) }
                }
            }
            // Still stand-ins give way to the moving version once it plays.
            Canvas { context, size in
                let renderer = JourneySceneRenderer(size: size)
                scene.background.filter(\.isStill).forEach { renderer.draw($0, in: &context) }
            }
            .opacity(isAmbiencePlaying ? 0 : 1)
            Canvas { context, size in
                let renderer = JourneySceneRenderer(size: size)
                scene.completion.filter { !$0.isStill || !isAmbiencePlaying }.forEach { renderer.draw($0, in: &context) }
            }
            .opacity(isComplete ? 1 : 0)
            if isAmbiencePlaying {
                JourneySceneAmbienceView(ambience: scene.ambience)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: animatesLighting ? 0.8 : 0), value: isComplete)
        .task(id: target) {
            guard animatesLighting else { return }
            // Continue from what is on screen if a sweep was still running.
            shownBeforeSweep = min(shownCount(at: .now), Double(target))
            guard Double(target) > shownBeforeSweep else {
                sweepStart = nil
                return
            }
            sweepStart = .now
            try? await Task.sleep(nanoseconds: UInt64(Self.sweepDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            shownBeforeSweep = Double(target)
            sweepStart = nil
        }
        .accessibilityElement()
        .accessibilityLabel("\(scene.title), \(visibleSlots)칸 중 \(target)칸 채움")
    }

    private func shownCount(at date: Date) -> Double {
        guard animatesLighting else { return Double(target) }
        guard let sweepStart else { return shownBeforeSweep }
        let progress = min(max(date.timeIntervalSince(sweepStart) / Self.sweepDuration, 0), 1)
        let eased = 1 - pow(1 - progress, 3)
        return shownBeforeSweep + (Double(target) - shownBeforeSweep) * eased
    }
}

/// Maps the design canvas onto the view: scaled to the width and anchored to the bottom.
struct JourneySceneRenderer {
    let scale: CGFloat
    let transform: CGAffineTransform
    let size: CGSize

    init(size: CGSize) {
        self.size = size
        scale = size.width / JourneyScene.canvas.width
        transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: 0, ty: size.height - JourneyScene.canvas.height * scale)
    }

    func fillSky(_ colors: [SceneColor], in context: inout GraphicsContext) {
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: colors.map { Color($0) }), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    func draw(_ element: SceneElement, in context: inout GraphicsContext) {
        draw(element.path, color: element.color, lineWidth: element.lineWidth, glow: element.glow, in: &context)
    }

    /// `amount` 0 is off, 1 is fully on; values between blend the two.
    func draw(_ light: SceneLight, amount: Double, in context: inout GraphicsContext) {
        if amount < 1 {
            draw(light.offPath ?? light.path, color: light.offColor, lineWidth: light.lineWidth, glow: 0, in: &context)
        }
        guard amount > 0 else { return }
        var layer = context
        layer.opacity = amount
        draw(light.path, color: light.onColor, lineWidth: light.lineWidth, glow: light.glow, in: &layer)
        light.accents.forEach { draw($0, in: &layer) }
    }

    func draw(_ path: CGPath, color: SceneColor, lineWidth: CGFloat?, glow: CGFloat, in context: inout GraphicsContext) {
        let shape = Path(path).applying(transform)
        let paint = { (layer: inout GraphicsContext) in
            if let lineWidth {
                layer.stroke(shape, with: .color(Color(color)), style: StrokeStyle(lineWidth: lineWidth * scale, lineCap: .round, lineJoin: .round))
            } else {
                layer.fill(shape, with: .color(Color(color)))
            }
        }
        guard glow > 0 else {
            paint(&context)
            return
        }
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: Color(color), radius: glow * scale))
            paint(&layer)
        }
    }
}

extension Color {
    init(_ color: SceneColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.opacity)
    }
}

#Preview("12 months") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
            ForEach(1...12, id: \.self) { month in
                JourneySceneView(scene: JourneySceneCatalog.scene(for: month), year: 2026, litCount: 20, slotCount: 31)
                    .aspectRatio(JourneyScene.canvas.width / JourneyScene.canvas.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
