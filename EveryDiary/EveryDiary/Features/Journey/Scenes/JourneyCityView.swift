import SwiftUI

/// Draws the year's city at `stage` (0...12), scaled to the view width and anchored to the bottom.
struct JourneyCityView: View {
    let stage: Int

    var body: some View {
        Canvas { context, size in
            let renderer = JourneySceneRenderer(size: size, canvas: CGSize(width: JourneyCityScene.canvas.width, height: JourneyCityScene.bottom))
            renderer.fillSky(JourneyCityScene.sky(for: stage), in: &context)
            JourneyCityScene.elements(for: stage).forEach { renderer.draw($0, in: &context) }
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
