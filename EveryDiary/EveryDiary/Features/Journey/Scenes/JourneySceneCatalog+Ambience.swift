import CoreGraphics
import Foundation

/// Moving details that play over a month's picture once it is complete. They replace the picture's
/// still stand-ins (`SceneElement.isStill`), so each month gets a fuller moving version of the same idea.
/// Where two layers of one kind exist, the far layer is smaller, dimmer and slower to give depth.
extension JourneySceneCatalog {
    static func ambience(for month: Int) -> [SceneAmbience] {
        let white = SceneColor(0xFFFFFF)
        let faintWhite = SceneColor(0xFFFFFF, opacity: 0.55)
        let gold = SceneColor(0xFFE08A)
        let wholeSky = CGRect(x: 0, y: 60, width: 390, height: 640)
        switch month {
        case 1:
            // Smoke rises from each chimney of the village.
            let chimneys: [CGFloat] = [68, 144, 229, 307, 371]
            let chimneyTops: [CGFloat] = [552, 582, 525, 570, 550]
            let smoke = zip(chimneys, chimneyTops).map { x, top in
                SceneAmbience(.rise, .dot, colors: [SceneColor(0xFFFFFF, opacity: 0.4)], count: 5, area: CGRect(x: x - 4, y: top - 80, width: 12, height: 80),
                              size: 3...6.5, speed: 11)
            }
            return smoke + [SceneAmbience(.fall, .dot, colors: [faintWhite], count: 70, area: wholeSky, size: 0.8...1.6, speed: 16),
                            SceneAmbience(.fall, .snowflake, colors: [white], count: 55, area: wholeSky, size: 2.5...4.5, speed: 34)]
        case 2:
            return [SceneAmbience(.twinkle, .sparkle, colors: [gold, white], count: 30, area: CGRect(x: 0, y: 90, width: 390, height: 200), size: 3...5.5, glow: 4),
                    SceneAmbience(.rise, .dot, colors: [SceneColor(0xFFCF7A, opacity: 0.8)], count: 26, area: CGRect(x: 0, y: 300, width: 390, height: 360),
                                  size: 0.8...1.6, speed: 10, glow: 3)]
        case 3:
            return [SceneAmbience(.wander, .butterfly, colors: [SceneColor(0xFFD43B), SceneColor(0xFF8FAB), SceneColor(0x9BE7FF), SceneColor(0xC9A6FF)], count: 7,
                                  area: CGRect(x: 30, y: 380, width: 330, height: 220), size: 1...1.2),
                    SceneAmbience(.rise, .dot, colors: [SceneColor(0xFFF4C9, opacity: 0.85)], count: 40, area: CGRect(x: 0, y: 420, width: 390, height: 270),
                                  size: 1...2, speed: 12, glow: 3)]
        case 4:
            return [SceneAmbience(.fall, .petal, colors: [SceneColor(0xFFD1DF, opacity: 0.6)], count: 45, area: CGRect(x: 0, y: 200, width: 390, height: 500),
                                  size: 2.5...3.5, speed: 18),
                    SceneAmbience(.fall, .petal, colors: [SceneColor(0xFFC4D6), SceneColor(0xFFE1EA)], count: 60, area: CGRect(x: 0, y: 200, width: 390, height: 500),
                                  size: 4.5...6.5, speed: 32)]
        case 5:
            return [SceneAmbience(.twinkle, .sparkle, colors: [white, gold], count: 34, area: CGRect(x: 0, y: 70, width: 390, height: 210), size: 3...5.5, glow: 4),
                    SceneAmbience(.rise, .dot, colors: [SceneColor(0xFFB65C, opacity: 0.85)], count: 20, area: CGRect(x: 100, y: 520, width: 190, height: 150),
                                  size: 1...1.8, speed: 9, glow: 3)]
        case 6:
            return [SceneAmbience(.wander, .dot, colors: [SceneColor(0xE9FF8C, opacity: 0.6)], count: 50, area: CGRect(x: 0, y: 240, width: 390, height: 420),
                                  size: 1...1.8, glow: 5),
                    SceneAmbience(.wander, .dot, colors: [SceneColor(0xE9FF8C)], count: 40, area: CGRect(x: 0, y: 280, width: 390, height: 400),
                                  size: 2...3.2, glow: 9)]
        case 7:
            return [SceneAmbience(.twinkle, .sparkle, colors: [white, SceneColor(0xFFF3B0)], count: 40, area: CGRect(x: 0, y: 90, width: 390, height: 420), size: 2...4.5, glow: 4),
                    SceneAmbience(.shootingStar, .dot, colors: [white], count: 3, area: CGRect(x: 60, y: 90, width: 330, height: 200), size: 1...1)]
        case 8:
            let colors = [SceneColor(0xFF6B6B), SceneColor(0xFFD93D), SceneColor(0x6BCBFF), SceneColor(0xB388FF), SceneColor(0x7CFFB2), SceneColor(0xFF9F68)]
            return [SceneAmbience(.burst, .firework, colors: colors, count: 9, area: CGRect(x: 30, y: 200, width: 330, height: 260), size: 24...44, glow: 8),
                    SceneAmbience(.burst, .firework, colors: [gold, SceneColor(0xFF9FD0)], count: 2, area: CGRect(x: 110, y: 230, width: 170, height: 80), size: 60...80, glow: 12)]
        case 9:
            return [SceneAmbience(.rise, .lantern, colors: [SceneColor(0xFFB65C, opacity: 0.7)], count: 30, area: CGRect(x: 0, y: 110, width: 390, height: 520),
                                  size: 0.25...0.45, speed: 8, glow: 4),
                    SceneAmbience(.rise, .lantern, colors: [SceneColor(0xFFB65C)], count: 22, area: CGRect(x: 0, y: 150, width: 390, height: 520),
                                  size: 0.6...1, speed: 15, glow: 8)]
        case 10:
            let leaves = [SceneColor(0xE8452C), SceneColor(0xF28C28), SceneColor(0xF6C343), SceneColor(0xC2362B)]
            return [SceneAmbience(.fall, .mapleLeaf, colors: leaves.map { $0.withOpacity(0.6) }, count: 30, area: CGRect(x: 0, y: 220, width: 390, height: 480),
                                  size: 4...5.5, speed: 16),
                    SceneAmbience(.fall, .mapleLeaf, colors: leaves, count: 40, area: CGRect(x: 0, y: 220, width: 390, height: 480), size: 7...10, speed: 30),
                    SceneAmbience(.wander, .bird, colors: [SceneColor(0x2A1A3D, opacity: 0.8)], count: 5, area: CGRect(x: 50, y: 200, width: 150, height: 70), size: 6...8)]
        case 11:
            return [SceneAmbience(.twinkle, .dot, colors: [white], count: 50, area: CGRect(x: 0, y: 70, width: 390, height: 260), size: 1...2, glow: 3),
                    SceneAmbience(.shootingStar, .dot, colors: [white], count: 2, area: CGRect(x: 60, y: 80, width: 330, height: 160), size: 1...1)]
        default:
            return [SceneAmbience(.fall, .dot, colors: [faintWhite], count: 70, area: wholeSky, size: 0.8...1.6, speed: 16),
                    SceneAmbience(.fall, .snowflake, colors: [white], count: 60, area: wholeSky, size: 2.5...5, speed: 34),
                    SceneAmbience(.twinkle, .sparkle, colors: [gold], count: 8, area: CGRect(x: 155, y: 258, width: 80, height: 64), size: 3...5.5, glow: 6)]
        }
    }
}
