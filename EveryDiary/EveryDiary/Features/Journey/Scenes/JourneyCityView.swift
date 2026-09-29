import SwiftUI

/// Draws the year's city at `stage` (0...12), scaled to the view width and anchored to the bottom.
/// With `isAnimating`, the stage's gentle movement plays at a capped frame rate; otherwise the picture stays still.
struct JourneyCityView: View {
    let stage: Int
    var isAnimating = false

    private static let designSize = CGSize(width: JourneyCityScene.canvas.width, height: JourneyCityScene.bottom)

    var body: some View {
        ZStack {
            Canvas { context, size in
                let renderer = JourneySceneRenderer(size: size, canvas: Self.designSize)
                renderer.fillSky(JourneyCityScene.sky(for: stage), in: &context)
                JourneyCityScene.elements(for: stage)
                    .filter { !isAnimating || !$0.isStill }
                    .forEach { renderer.draw($0, in: &context) }
            }
            if isAnimating {
                // 30 frames per second is plenty for drifting clouds and cars and keeps the battery cost low.
                JourneySceneAmbienceView(ambience: JourneyCityScene.ambience(for: stage), canvas: Self.designSize, minimumInterval: 1.0 / 30)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(stage)단계 도시, \(JourneyCityScene.stageTitles[min(max(stage, 0), JourneyYearProgress.finalStage)])")
    }
}

#Preview("Stages") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(0...12, id: \.self) { stage in
                JourneyCityView(stage: stage)
                    .aspectRatio(JourneyCityScene.canvas.width / JourneyCityScene.canvas.height, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}
