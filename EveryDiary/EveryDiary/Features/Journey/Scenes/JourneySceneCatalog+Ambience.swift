import CoreGraphics
import Foundation

/// Moving details that play over a month's picture once it is complete.
extension JourneySceneCatalog {
    static func ambience(for month: Int) -> [SceneAmbience] {
        let white = SceneColor(0xFFFFFF)
        let gold = SceneColor(0xFFE08A)
        switch month {
        case 1:
            return [SceneAmbience(.fall, .snowflake, colors: [white], count: 40, area: CGRect(x: 0, y: 80, width: 390, height: 620), size: 2...4, speed: 26)]
        case 2:
            return [SceneAmbience(.twinkle, .sparkle, colors: [gold, white], count: 16, area: CGRect(x: 0, y: 100, width: 390, height: 160), size: 3...5, glow: 4)]
        case 3:
            return [SceneAmbience(.wander, .butterfly, colors: [SceneColor(0xFFD43B), SceneColor(0xFF8FAB), SceneColor(0x9BE7FF)], count: 4,
                                  area: CGRect(x: 40, y: 400, width: 310, height: 170), size: 1...1.2),
                    SceneAmbience(.rise, .dot, colors: [SceneColor(0xFFF4C9, opacity: 0.8)], count: 18, area: CGRect(x: 0, y: 460, width: 390, height: 230),
                                  size: 1...1.8, speed: 12, glow: 3)]
        case 4:
            return [SceneAmbience(.fall, .petal, colors: [SceneColor(0xFFC4D6), SceneColor(0xFFE1EA)], count: 36,
                                  area: CGRect(x: 0, y: 250, width: 390, height: 450), size: 4...6, speed: 28)]
        case 5:
            return [SceneAmbience(.twinkle, .sparkle, colors: [white, gold], count: 18, area: CGRect(x: 0, y: 80, width: 390, height: 190), size: 3...5, glow: 4)]
        case 6:
            return [SceneAmbience(.wander, .dot, colors: [SceneColor(0xE9FF8C)], count: 30, area: CGRect(x: 0, y: 280, width: 390, height: 380),
                                  size: 1.5...3, glow: 8)]
        case 7:
            return [SceneAmbience(.twinkle, .sparkle, colors: [white], count: 20, area: CGRect(x: 0, y: 100, width: 390, height: 380), size: 2...4, glow: 4),
                    SceneAmbience(.shootingStar, .dot, colors: [white], count: 2, area: CGRect(x: 60, y: 100, width: 330, height: 160), size: 1...1)]
        case 8:
            return [SceneAmbience(.burst, .firework, colors: [SceneColor(0xFF6B6B), SceneColor(0xFFD93D), SceneColor(0x6BCBFF), SceneColor(0xB388FF),
                                                           SceneColor(0x7CFFB2), SceneColor(0xFF9F68)],
                                  count: 5, area: CGRect(x: 40, y: 200, width: 310, height: 250), size: 22...42, glow: 8)]
        case 9:
            return [SceneAmbience(.rise, .lantern, colors: [SceneColor(0xFFB65C)], count: 12, area: CGRect(x: 0, y: 150, width: 390, height: 500),
                                  size: 0.5...0.9, speed: 14, glow: 8)]
        case 10:
            return [SceneAmbience(.fall, .mapleLeaf, colors: [SceneColor(0xE8452C), SceneColor(0xF28C28), SceneColor(0xF6C343)], count: 22,
                                  area: CGRect(x: 0, y: 300, width: 390, height: 400), size: 6...9, speed: 26)]
        case 11:
            return [SceneAmbience(.twinkle, .dot, colors: [white], count: 26, area: CGRect(x: 0, y: 80, width: 390, height: 240), size: 1...1.8, glow: 3),
                    SceneAmbience(.shootingStar, .dot, colors: [white], count: 1, area: CGRect(x: 60, y: 90, width: 330, height: 140), size: 1...1)]
        default:
            return [SceneAmbience(.fall, .snowflake, colors: [white], count: 45, area: CGRect(x: 0, y: 80, width: 390, height: 620), size: 2...4.5, speed: 30),
                    SceneAmbience(.twinkle, .sparkle, colors: [gold], count: 6, area: CGRect(x: 160, y: 262, width: 70, height: 56), size: 3...5, glow: 6)]
        }
    }
}
