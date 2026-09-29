import SwiftUI

/// Draws a month's picture with `litCount` lights on, out of `slotCount` (the days of that month).
/// With `animatesLighting`, lights turn on one after another up to `litCount`.
/// When every slot is lit, the scene's completion details fade in.
struct JourneySceneView: View {
    let scene: JourneyScene
    let litCount: Int
    let slotCount: Int
    var animatesLighting = false

    @State private var shownCount = 0

    private var target: Int { min(max(litCount, 0), slotCount, scene.lights.count) }
    private var lit: Int { animatesLighting ? shownCount : target }
    private var isComplete: Bool { slotCount > 0 && lit >= min(slotCount, scene.lights.count) }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let renderer = SceneRenderer(size: size)
                renderer.fillSky(scene.sky, in: &context)
                scene.background.forEach { renderer.draw($0, in: &context) }
                for (index, light) in scene.lights.prefix(slotCount).enumerated() {
                    renderer.draw(light, isOn: index < lit, in: &context)
                }
                scene.foreground.forEach { renderer.draw($0, in: &context) }
            }
            Canvas { context, size in
                let renderer = SceneRenderer(size: size)
                scene.completion.forEach { renderer.draw($0, in: &context) }
            }
            .opacity(isComplete ? 1 : 0)
            .animation(.easeIn(duration: animatesLighting ? 1.2 : 0), value: isComplete)
        }
        .task(id: target) {
            guard animatesLighting else { return }
            if shownCount > target { shownCount = target }
            while shownCount < target {
                try? await Task.sleep(nanoseconds: 90_000_000)
                guard !Task.isCancelled else { return }
                shownCount += 1
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(scene.title), \(slotCount)칸 중 \(target)칸 채움")
    }
}

/// Maps the design canvas onto the view: scaled to the width and anchored to the bottom.
private struct SceneRenderer {
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

    func draw(_ light: SceneLight, isOn: Bool, in context: inout GraphicsContext) {
        guard isOn else {
            draw(light.offPath ?? light.path, color: light.offColor, lineWidth: light.lineWidth, glow: 0, in: &context)
            return
        }
        draw(light.path, color: light.onColor, lineWidth: light.lineWidth, glow: light.glow, in: &context)
        light.accents.forEach { draw($0, in: &context) }
    }

    private func draw(_ path: CGPath, color: SceneColor, lineWidth: CGFloat?, glow: CGFloat, in context: inout GraphicsContext) {
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

private extension Color {
    init(_ color: SceneColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.opacity)
    }
}

#Preview("12 months") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
            ForEach(1...12, id: \.self) { month in
                JourneySceneView(scene: JourneySceneCatalog.scene(for: month), litCount: 31, slotCount: 31)
                    .aspectRatio(JourneyScene.canvas.width / JourneyScene.canvas.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
