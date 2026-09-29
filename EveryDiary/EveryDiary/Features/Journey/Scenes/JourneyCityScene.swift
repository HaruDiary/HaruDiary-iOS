import CoreGraphics
import Foundation

/// The year's city. It starts as empty land and gains a part at every stage (see `JourneyYearProgress`);
/// some early parts, such as the dead tree, disappear once the city turns green.
/// Coordinates run 0...390 × 40...300 (y grows downward, horizon near y 205); `canvas` shows the lower 260 points.
enum JourneyCityScene {
    /// The visible area: the lower 260 points of the drawing, so the sky above y 40 is cut off.
    static let canvas = CGSize(width: 390, height: 260)
    /// The bottom edge of the drawing, which lines up with the bottom of the view.
    static let bottom: CGFloat = 300

    /// Stage names follow the journey: from setting out to arriving.
    static let stageTitles = [
        "여정의 시작", "첫걸음", "길을 따라", "작은 쉼터", "밤길을 밝히며", "푸르게 물든 길", "북적이는 거리",
        "머무는 사람들", "강을 건너", "시간이 쌓인 광장", "높아지는 꿈", "설레는 하루", "빛나는 도착"
    ]

    /// Day sky while the land is empty, evening once the street lights are up, night for the finished city.
    static func sky(for stage: Int) -> [SceneColor] {
        switch stage {
        case ..<4: return [SceneColor(0x5E8FC0), SceneColor(0xA9C8DE), SceneColor(0xEAD9B5)]
        case ..<12: return [SceneColor(0x2B2350), SceneColor(0x6B4A7E), SceneColor(0xE89A6B)]
        default: return [SceneColor(0x0E1233), SceneColor(0x2B2560), SceneColor(0x7A4F84)]
        }
    }

    /// Everything shown at `stage`, back to front.
    static func elements(for stage: Int) -> [SceneElement] {
        pieces.enumerated()
            .filter { $0.element.stage <= stage && ($0.element.until.map { stage < $0 } ?? true) }
            .sorted { ($0.element.layer, $0.offset) < ($1.element.layer, $1.offset) }
            .map(\.element.element)
    }

    struct Piece {
        let stage: Int
        /// The first stage without this piece.
        let until: Int?
        /// Drawing depth: lower is further back.
        let layer: Int
        let element: SceneElement
    }

    private enum Layer {
        static let skyline = 1, hills = 2, ground = 3, groundCover = 4, water = 5
        static let backBuildings = 6, buildings = 7, trees = 8, road = 9, roadDetails = 10, lamps = 11, front = 12, sky = 13
    }

    static let pieces: [Piece] = {
        var pieces: [Piece] = []
        func add(_ stage: Int, _ layer: Int, _ element: SceneElement, until: Int? = nil) {
            pieces.append(Piece(stage: stage, until: until, layer: layer, element: element))
        }

        // 0 · 여정의 시작 (empty land): dry hills, cracked ground, rocks and a dead tree under a day sky.
        add(0, Layer.sky, SceneElement(ScenePath.circle(320, 70, 18), SceneColor(0xFFE9B0), glow: 12), until: 4)
        add(4, Layer.sky, SceneElement(ScenePath.circle(332, 66, 11), SceneColor(0xFFF4D6), glow: 10))
        add(0, Layer.hills, SceneElement(ScenePath.ellipse(-60, 170, 260, 80), SceneColor(0xB08466)))
        add(0, Layer.hills, SceneElement(ScenePath.ellipse(150, 178, 300, 70), SceneColor(0xA07A5E)))
        add(0, Layer.ground, SceneElement(ScenePath.rect(0, 205, 390, 95), SceneColor(0xC9A26E)))
        add(0, Layer.groundCover, SceneElement(ScenePath.group([
            ScenePath.line([(40, 230), (52, 236), (48, 244), (60, 250)]), ScenePath.line([(170, 290), (182, 284), (196, 292)]),
            ScenePath.line([(250, 226), (262, 232), (258, 240)]), ScenePath.line([(120, 240), (134, 236)])
        ]), SceneColor(0xA8834F), lineWidth: 1), until: 5)
        add(0, Layer.front, SceneElement(ScenePath.group([ScenePath.ellipse(52, 286, 20, 9), ScenePath.ellipse(318, 289, 15, 7), ScenePath.ellipse(246, 285, 10, 5)]),
                                         SceneColor(0x8C7B6B)), until: 5)
        add(0, Layer.front, SceneElement(ScenePath.group([
            ScenePath.line([(362, 298), (362, 262)]), ScenePath.line([(362, 276), (374, 266)]), ScenePath.line([(362, 270), (352, 258)])
        ]), SceneColor(0x5E4636), lineWidth: 2.5), until: 5)

        // 1 · 첫걸음 (the first road)
        add(1, Layer.road, SceneElement(ScenePath.rect(0, 262, 390, 18), SceneColor(0x3E3B45)))
        add(1, Layer.roadDetails, SceneElement(ScenePath.group(stride(from: CGFloat(6), to: 390, by: 24).map { ScenePath.line([($0, 271), ($0 + 12, 271)]) }),
                                               SceneColor(0xF2D16B), lineWidth: 1.5))

        // 2 · 길을 따라 (street trees)
        let treeXs: [CGFloat] = [12, 56, 100, 144, 188, 232, 276, 366]
        add(2, Layer.trees, SceneElement(ScenePath.group(treeXs.map { ScenePath.rect($0 - 1.5, 248, 3, 14) }), SceneColor(0x6B4A35)))
        add(2, Layer.trees, SceneElement(ScenePath.group(treeXs.map { ScenePath.circle($0, 243, 9) }), SceneColor(0x4E9A5A)))
        add(2, Layer.trees, SceneElement(ScenePath.group(treeXs.map { ScenePath.circle($0 - 3, 240, 4) }), SceneColor(0x6DB86F)))

        // 3 · 작은 쉼터 (houses)
        let houses: [(x: CGFloat, width: CGFloat, height: CGFloat, wall: UInt32, roof: UInt32)] = [
            (20, 34, 24, 0xF2E3C6, 0xC0563F), (62, 30, 20, 0xE8D5B5, 0x4F6D9A), (234, 34, 24, 0xF2E3C6, 0x4F6D9A), (276, 26, 20, 0xE8D5B5, 0xC0563F)
        ]
        for house in houses {
            let top = 258 - house.height
            add(3, Layer.buildings, SceneElement(ScenePath.rect(house.x, top, house.width, house.height), SceneColor(house.wall)))
            add(3, Layer.buildings, SceneElement(ScenePath.polygon([(house.x - 3, top), (house.x + house.width / 2, top - 12), (house.x + house.width + 3, top)]), SceneColor(house.roof)))
            add(3, Layer.buildings, SceneElement(ScenePath.group([ScenePath.rect(house.x + 5, top + 6, 6, 6), ScenePath.rect(house.x + house.width - 11, top + 6, 6, 6)]),
                                                 SceneColor(0xFFD27A), glow: 3))
            add(3, Layer.buildings, SceneElement(ScenePath.rect(house.x + house.width / 2 - 3, 258 - 9, 6, 9), SceneColor(0x7A5238)))
        }

        // 4 · 밤길을 밝히며: lamps between the trees; the sky turns to evening.
        let lampXs: [CGFloat] = [34, 78, 122, 166, 210, 254, 352]
        add(4, Layer.lamps, SceneElement(ScenePath.group(lampXs.map { ScenePath.line([($0, 262), ($0, 236), ($0 + 4, 236)]) }), SceneColor(0x2E2A36), lineWidth: 1.5))
        add(4, Layer.lamps, SceneElement(ScenePath.group(lampXs.map { ScenePath.circle($0 + 4, 238, 2.6) }), SceneColor(0xFFE08A), glow: 6))

        // 5 · 푸르게 물든 길: the land turns green, a pond and bushes appear; the wasteland is gone.
        add(5, Layer.hills, SceneElement(ScenePath.ellipse(-60, 170, 260, 80), SceneColor(0x5E8E50)))
        add(5, Layer.hills, SceneElement(ScenePath.ellipse(150, 178, 300, 70), SceneColor(0x4F7E45)))
        add(5, Layer.groundCover, SceneElement(ScenePath.rect(0, 205, 390, 95), SceneColor(0x7DB26A)))
        add(5, Layer.front, SceneElement(ScenePath.ellipse(18, 284, 92, 13), SceneColor(0x5AA7C8)))
        add(5, Layer.front, SceneElement(ScenePath.ellipse(36, 287, 30, 3), SceneColor(0xBFE6F5, opacity: 0.8)))
        add(5, Layer.front, SceneElement(ScenePath.group([ScenePath.circle(126, 292, 8), ScenePath.circle(140, 294, 6), ScenePath.circle(206, 293, 7), ScenePath.circle(222, 295, 5),
                                                          ScenePath.circle(376, 292, 8)]), SceneColor(0x3F8A4A)))
        add(5, Layer.front, SceneElement(ScenePath.group([ScenePath.circle(124, 289, 1.6), ScenePath.circle(142, 291, 1.6), ScenePath.circle(208, 290, 1.6),
                                                          ScenePath.circle(374, 289, 1.6)]), SceneColor(0xFF9EB5)))

        // 6 · 북적이는 거리: shops with striped awnings between the houses, and cars on the road.
        let shops: [(x: CGFloat, width: CGFloat, height: CGFloat, awning: UInt32)] = [(112, 34, 22, 0xE8505B), (150, 36, 26, 0x2FA7A0), (190, 34, 22, 0xF2B233)]
        for shop in shops {
            let top = 258 - shop.height
            add(6, Layer.buildings, SceneElement(ScenePath.rect(shop.x, top, shop.width, shop.height), SceneColor(0xF4EBDD)))
            add(6, Layer.buildings, SceneElement(ScenePath.rect(shop.x + 4, top + 13, shop.width - 8, 8), SceneColor(0xFFE7A8), glow: 3))
            add(6, Layer.buildings, SceneElement(ScenePath.rect(shop.x - 2, top + 5, shop.width + 4, 6, corner: 1), SceneColor(shop.awning)))
            add(6, Layer.buildings, SceneElement(ScenePath.group(stride(from: shop.x + 2, to: shop.x + shop.width, by: 6).map { ScenePath.rect($0, top + 5, 2.5, 6) }),
                                                 SceneColor(0xFFFFFF, opacity: 0.8)))
            add(6, Layer.buildings, SceneElement(ScenePath.rect(shop.x + 6, top + 1, shop.width - 12, 3.5), SceneColor(0x3E3B45)))
        }
        for (x, y, color) in [(CGFloat(52), CGFloat(265), UInt32(0xE8505B)), (238, 272, 0x4DABF7)] {
            add(6, Layer.roadDetails, SceneElement(ScenePath.group([ScenePath.rect(x, y, 20, 6, corner: 2), ScenePath.rect(x + 4, y - 4, 11, 5, corner: 2)]), SceneColor(color)))
            add(6, Layer.roadDetails, SceneElement(ScenePath.group([ScenePath.circle(x + 4, y + 6.5, 2), ScenePath.circle(x + 16, y + 6.5, 2)]), SceneColor(0x1E1B24)))
            add(6, Layer.roadDetails, SceneElement(ScenePath.circle(x + 20, y + 2.5, 1.3), SceneColor(0xFFF3B0), glow: 4))
        }

        // 7 · 머무는 사람들: mid-rise blocks rise behind the street.
        for (x, width, top) in [(CGFloat(8), CGFloat(40), CGFloat(150)), (150, 46, 140), (236, 40, 160)] {
            add(7, Layer.backBuildings, SceneElement(ScenePath.rect(x, top, width, 258 - top), SceneColor(0x6F6488)))
            add(7, Layer.backBuildings, SceneElement(windowGrid(x: x, width: width, top: top + 6, bottom: 222, spacing: CGSize(width: 9, height: 11), size: CGSize(width: 4, height: 6)),
                                                     SceneColor(0xFFE08A, opacity: 0.9), glow: 2))
        }

        // 8 · 강을 건너: a river widens toward the front and the road crosses it on a bridge.
        add(8, Layer.water, SceneElement(ScenePath.polygon([(310, 205), (326, 205), (352, 300), (296, 300)]), SceneColor(0x5B9FD0)))
        add(8, Layer.water, SceneElement(ScenePath.group([ScenePath.line([(314, 222), (320, 222)]), ScenePath.line([(306, 292), (320, 292)]), ScenePath.line([(328, 288), (338, 288)])]),
                                         SceneColor(0xBFE6F5, opacity: 0.7), lineWidth: 1))
        add(8, Layer.roadDetails, SceneElement(ScenePath.group([ScenePath.line([(296, 262), (350, 262)]), ScenePath.line([(296, 280), (350, 280)])]
                                                               + stride(from: CGFloat(298), through: 348, by: 10).map { ScenePath.line([($0, 258), ($0, 262)]) }),
                                               SceneColor(0xE8E4F0), lineWidth: 1.4))
        add(8, Layer.roadDetails, SceneElement(ScenePath.line([(296, 258), (350, 258)]), SceneColor(0xE8E4F0), lineWidth: 1))

        // 9 · 시간이 쌓인 광장 (clock tower)
        add(9, Layer.buildings, SceneElement(ScenePath.rect(356, 188, 22, 70), SceneColor(0xD8C3A0)))
        add(9, Layer.buildings, SceneElement(ScenePath.polygon([(352, 188), (367, 170), (382, 188)]), SceneColor(0x8E3B2F)))
        add(9, Layer.buildings, SceneElement(ScenePath.circle(367, 203, 7), SceneColor(0xFFF8E6), glow: 4))
        add(9, Layer.buildings, SceneElement(ScenePath.group([ScenePath.line([(367, 203), (367, 198)]), ScenePath.line([(367, 203), (371, 205)])]), SceneColor(0x3E3B45), lineWidth: 1))
        add(9, Layer.buildings, SceneElement(ScenePath.group([ScenePath.rect(361, 220, 4, 7), ScenePath.rect(369, 220, 4, 7), ScenePath.rect(361, 234, 4, 7), ScenePath.rect(369, 234, 4, 7)]),
                                             SceneColor(0xFFD27A), glow: 2))

        // 10 · 높아지는 꿈: a skyline of towers behind the hills.
        for (x, width, top) in [(CGFloat(26), CGFloat(24), CGFloat(110)), (54, 30, 88), (92, 22, 120), (248, 28, 98), (282, 24, 124), (338, 30, 112)] {
            add(10, Layer.skyline, SceneElement(ScenePath.rect(x, top, width, 205 - top), SceneColor(0x4A3F6B)))
            add(10, Layer.skyline, SceneElement(windowGrid(x: x, width: width, top: top + 5, bottom: 175, spacing: CGSize(width: 7, height: 9), size: CGSize(width: 3, height: 4)),
                                                SceneColor(0xFFD98A, opacity: 0.8)))
        }

        // 11 · 설레는 하루: a Ferris wheel.
        let wheel = CGPoint(x: 110, y: 165)
        add(11, Layer.backBuildings, SceneElement(ScenePath.group([ScenePath.line([(wheel.x, wheel.y), (94, 222)]), ScenePath.line([(wheel.x, wheel.y), (126, 222)])]),
                                                  SceneColor(0xD8D2E6), lineWidth: 2))
        add(11, Layer.backBuildings, SceneElement(ScenePath.group((0..<8).map { index -> CGPath in
            let angle = CGFloat(index) * .pi / 4
            return ScenePath.line([(wheel.x, wheel.y), (wheel.x + cos(angle) * 32, wheel.y + sin(angle) * 32)])
        }), SceneColor(0xD8D2E6, opacity: 0.8), lineWidth: 1))
        add(11, Layer.backBuildings, SceneElement(ScenePath.circle(wheel.x, wheel.y, 32), SceneColor(0xF2A6C8), lineWidth: 2, glow: 4))
        let cabinColors: [UInt32] = [0xFF6B6B, 0xFFD93D, 0x6BCBFF, 0x7CFFB2]
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 + .pi / 8
            add(11, Layer.backBuildings, SceneElement(ScenePath.circle(wheel.x + cos(angle) * 32, wheel.y + sin(angle) * 32, 3.2), SceneColor(cabinColors[index % 4]), glow: 3))
        }
        add(11, Layer.backBuildings, SceneElement(ScenePath.circle(wheel.x, wheel.y, 3), SceneColor(0xFFF3B0)))

        // 12 · 빛나는 도착: a landmark tower, hot-air balloons and fireworks in the night sky.
        add(12, Layer.skyline, SceneElement(ScenePath.polygon([(182, 205), (187, 82), (203, 82), (208, 205)]), SceneColor(0x5B4E86)))
        add(12, Layer.skyline, SceneElement(ScenePath.ellipse(178, 68, 34, 16), SceneColor(0x7A6CA6)))
        add(12, Layer.skyline, SceneElement(ScenePath.rect(182, 73, 26, 4, corner: 2), SceneColor(0xFFE08A), glow: 6))
        add(12, Layer.skyline, SceneElement(ScenePath.line([(195, 68), (195, 52)]), SceneColor(0x7A6CA6), lineWidth: 2))
        add(12, Layer.skyline, SceneElement(ScenePath.circle(195, 51, 2.4), SceneColor(0xFF4D4D), glow: 6))
        add(12, Layer.skyline, SceneElement(ScenePath.group(stride(from: CGFloat(92), to: 200, by: 10).map { ScenePath.rect(192, $0, 6, 5) }), SceneColor(0xFFE9A0), glow: 3))
        for (x, y, color) in [(CGFloat(60), CGFloat(82), UInt32(0xFF8FAB)), (262, 70, 0x6BCBFF), (140, 62, 0xFFD43B)] {
            add(12, Layer.sky, SceneElement(ScenePath.ellipse(x - 9, y - 11, 18, 21), SceneColor(color)))
            add(12, Layer.sky, SceneElement(ScenePath.group([ScenePath.line([(x - 6, y + 7), (x - 3, y + 14)]), ScenePath.line([(x + 6, y + 7), (x + 3, y + 14)])]),
                                            SceneColor(0xE8E4F0), lineWidth: 0.8))
            add(12, Layer.sky, SceneElement(ScenePath.rect(x - 3.5, y + 14, 7, 5, corner: 1), SceneColor(0x8B5E3C)))
        }
        for (x, y, color) in [(CGFloat(96), CGFloat(60), UInt32(0xFFD93D)), (300, 104, 0xB388FF)] {
            add(12, Layer.sky, SceneElement(ScenePath.group((0..<12).map { index -> CGPath in
                let angle = CGFloat(index) * .pi / 6
                return ScenePath.line([(x + cos(angle) * 5, y + sin(angle) * 5), (x + cos(angle) * 15, y + sin(angle) * 15)])
            }), SceneColor(color), lineWidth: 1.4, glow: 6))
        }
        return pieces
    }()

    private static func windowGrid(x: CGFloat, width: CGFloat, top: CGFloat, bottom: CGFloat, spacing: CGSize, size: CGSize) -> CGPath {
        let columns = max(Int((width - 4) / spacing.width), 1)
        let left = x + (width - CGFloat(columns - 1) * spacing.width - size.width) / 2
        var windows: [CGPath] = []
        for y in stride(from: top, through: bottom - size.height, by: spacing.height) {
            for column in 0..<columns {
                windows.append(ScenePath.rect(left + CGFloat(column) * spacing.width, y, size.width, size.height))
            }
        }
        return ScenePath.group(windows)
    }
}
