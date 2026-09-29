import SwiftUI

/// Draws a month's picture with `litCount` lights on, out of `slotCount` (the days of that month).
/// With `animatesLighting`, lights turn on one after another up to `litCount`.
struct JourneySceneView: View {
    let scene: JourneyScene
    let litCount: Int
    let slotCount: Int
    var animatesLighting = false

    @State private var shownCount = 0

    private var target: Int { min(max(litCount, 0), slotCount, scene.lights.count) }

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size, lit: animatesLighting ? shownCount : target)
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

    private func draw(in context: inout GraphicsContext, size: CGSize, lit: Int) {
        let skyStops = scene.sky.map { Color($0) }
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: skyStops), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        // Scaled to the width and anchored to the bottom; any extra height above shows sky.
        let scale = size.width / JourneyScene.canvas.width
        let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: 0, ty: size.height - JourneyScene.canvas.height * scale)

        func draw(_ path: CGPath, color: SceneColor, lineWidth: CGFloat?, in context: inout GraphicsContext) {
            let shape = Path(path).applying(transform)
            if let lineWidth {
                context.stroke(shape, with: .color(Color(color)), style: StrokeStyle(lineWidth: lineWidth * scale, lineCap: .round, lineJoin: .round))
            } else {
                context.fill(shape, with: .color(Color(color)))
            }
        }

        for element in scene.background {
            draw(element.path, color: element.color, lineWidth: element.lineWidth, in: &context)
        }
        for (index, light) in scene.lights.prefix(slotCount).enumerated() {
            if index < lit {
                context.drawLayer { layer in
                    if light.glow > 0 {
                        layer.addFilter(.shadow(color: Color(light.onColor), radius: light.glow * scale))
                    }
                    draw(light.path, color: light.onColor, lineWidth: light.lineWidth, in: &layer)
                }
            } else {
                draw(light.offPath ?? light.path, color: light.offColor, lineWidth: light.lineWidth, in: &context)
            }
        }
        for element in scene.foreground {
            draw(element.path, color: element.color, lineWidth: element.lineWidth, in: &context)
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
                JourneySceneView(scene: JourneySceneCatalog.scene(for: month), litCount: 20, slotCount: 31)
                    .aspectRatio(JourneyScene.canvas.width / JourneyScene.canvas.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
