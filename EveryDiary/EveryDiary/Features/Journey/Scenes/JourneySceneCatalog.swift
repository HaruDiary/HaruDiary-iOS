import CoreGraphics
import Foundation

/// The twelve monthly pictures. Coordinates use `JourneyScene.canvas` (390 × 700, y grows downward).
/// Light order is the order in which diary days fill the picture; `completion` appears when the month is full.
enum JourneySceneCatalog {
    static func scene(for month: Int) -> JourneyScene {
        switch month {
        case 1: return snowyVillage
        case 2: return newYearLanterns
        case 3: return springMeadow
        case 4: return cherryBlossom
        case 5: return lotusLanterns
        case 6: return fireflyForest
        case 7: return summerSea
        case 8: return fireworks
        case 9: return harvestMoon
        case 10: return autumnMaple
        case 11: return cityNight
        default: return christmasTree
        }
    }

    // MARK: 1월 · 눈 내린 마을 — house windows light up; when full, an aurora, chimney smoke and a snowman

    static let snowyVillage: JourneyScene = {
        var random = SceneRandom(seed: 101)
        let snow = ScenePath.group((0..<45).map { _ in
            ScenePath.circle(random.next(0...390), random.next(90...640), random.next(1...2.2))
        })
        let houses: [(x: CGFloat, width: CGFloat, height: CGFloat, base: CGFloat, columns: Int, rows: Int)] = [
            (18, 70, 84, 668, 3, 2), (100, 60, 66, 676, 2, 2), (172, 78, 104, 664, 3, 3), (262, 58, 76, 672, 2, 3), (330, 52, 92, 666, 2, 3)
        ]
        var background: [SceneElement] = [
            SceneElement(ScenePath.circle(300, 190, 28), SceneColor(0xF4F1DE), glow: 12),
            SceneElement(snow, SceneColor(0xFFFFFF, opacity: 0.75), still: true),
            SceneElement(ScenePath.ellipse(-120, 560, 640, 300), SceneColor(0xB9C4DE)),
            SceneElement(ScenePath.ellipse(-60, 650, 510, 140), SceneColor(0xEEF2FA)),
            SceneElement(ScenePath.rect(0, 672, 390, 28), SceneColor(0xEEF2FA))
        ]
        var lights: [SceneLight] = []
        var smoke: [CGPath] = []
        for house in houses {
            let top = house.base - house.height
            let roof = house.width * 0.45
            let chimneyX = house.x + house.width * 0.65
            background.append(SceneElement(ScenePath.rect(chimneyX, top - roof * 0.9, 9, roof * 0.7), SceneColor(0x2A2440)))
            background.append(SceneElement(ScenePath.rect(house.x, top, house.width, house.height), SceneColor(0x3A3350)))
            let roofLine = [(house.x - 7, top + 1), (house.x + house.width / 2, top - roof), (house.x + house.width + 7, top + 1)]
            background.append(SceneElement(ScenePath.polygon(roofLine), SceneColor(0x2A2440)))
            background.append(SceneElement(ScenePath.line(roofLine), SceneColor(0xF4F7FD), lineWidth: 5))
            smoke += [ScenePath.circle(chimneyX + 6, top - roof - 6, 4), ScenePath.circle(chimneyX + 11, top - roof - 17, 5.5),
                      ScenePath.circle(chimneyX + 18, top - roof - 31, 7)]
            let gap = (house.width - CGFloat(house.columns) * 10) / CGFloat(house.columns + 1)
            for row in 0..<house.rows {
                for column in 0..<house.columns {
                    let x = house.x + gap + CGFloat(column) * (10 + gap)
                    let y = house.base - 26 - CGFloat(row) * 22
                    let frame = ScenePath.group([ScenePath.line([(x + 5, y), (x + 5, y + 12)]), ScenePath.line([(x, y + 6), (x + 10, y + 6)])])
                    lights.append(SceneLight(ScenePath.rect(x, y, 10, 12, corner: 1.5), on: SceneColor(0xFFD27A), off: SceneColor(0x262040), glow: 6,
                                             accents: [SceneElement(frame, SceneColor(0xB9853A), lineWidth: 1)]))
                }
            }
        }
        var flakes = SceneRandom(seed: 111)
        let bigSnow = ScenePath.group((0..<22).map { _ in
            ScenePath.star(flakes.next(0...390), flakes.next(100...560), outer: flakes.next(2.5...4), inner: 1.1, points: 6)
        })
        let completion: [SceneElement] = [
            // Aurora above the moon, so the moon stays clear.
            SceneElement(ScenePath.band(from: CGPoint(x: -20, y: 140), to: CGPoint(x: 410, y: 70), bend: 20, thickness: 34), SceneColor(0x6CFFC8, opacity: 0.2), glow: 18),
            SceneElement(ScenePath.band(from: CGPoint(x: -20, y: 200), to: CGPoint(x: 410, y: 105), bend: -10, thickness: 18), SceneColor(0xA394FF, opacity: 0.18), glow: 14),
            SceneElement(bigSnow, SceneColor(0xFFFFFF, opacity: 0.9), still: true),
            SceneElement(ScenePath.group(smoke), SceneColor(0xFFFFFF, opacity: 0.45), still: true),
            // Snowman in the lower right corner.
            SceneElement(ScenePath.group([ScenePath.circle(370, 688, 10), ScenePath.circle(370, 672, 7)]), SceneColor(0xFFFFFF)),
            SceneElement(ScenePath.group([ScenePath.rect(363, 663, 14, 3), ScenePath.rect(365, 654, 10, 10),
                                          ScenePath.circle(367.5, 671, 1), ScenePath.circle(372.5, 671, 1), ScenePath.circle(370, 686, 1.2), ScenePath.circle(370, 691, 1.2)]),
                         SceneColor(0x2A2440)),
            SceneElement(ScenePath.rect(363, 677, 14, 3, corner: 1.5), SceneColor(0xE8505B)),
            SceneElement(ScenePath.polygon([(370, 673), (377, 674.5), (370, 676)]), SceneColor(0xFF9A3C))
        ]
        return JourneyScene(month: 1, title: "눈 내린 마을", sky: [SceneColor(0x0E1B3D), SceneColor(0x3B4F7F), SceneColor(0x7C8DB5)],
                            background: background, lights: lights, completion: completion, ambience: ambience(for: 1))
    }()

    // MARK: 2월 · 설날 청사초롱 — blue-and-red lanterns; when full, the moon, a kite and lit hanok windows

    static let newYearLanterns: JourneyScene = {
        var background: [SceneElement] = [
            SceneElement(ScenePath.rect(20, 600, 150, 100), SceneColor(0x2E2146)),
            SceneElement(ScenePath.polygon([(0, 588), (20, 602), (170, 602), (190, 588), (160, 568), (30, 568)]), SceneColor(0x1A1230)),
            SceneElement(ScenePath.rect(212, 592, 166, 108), SceneColor(0x2E2146)),
            SceneElement(ScenePath.polygon([(192, 578), (212, 594), (378, 594), (398, 578), (362, 556), (246, 556)]), SceneColor(0x1A1230)),
            SceneElement(ScenePath.rect(0, 680, 390, 20), SceneColor(0x20162F))
        ]
        let gold = SceneColor(0xF2C14E)
        func lantern(_ p: CGPoint) -> SceneLight {
            SceneLight(ScenePath.rect(p.x - 8, p.y + 8, 16, 22, corner: 6), on: SceneColor(0x4F7DF5), off: SceneColor(0x3B2B57), glow: 10, accents: [
                SceneElement(ScenePath.rect(p.x - 8, p.y + 18, 16, 12, corner: 6), SceneColor(0xF0475A)),
                SceneElement(ScenePath.rect(p.x - 5, p.y + 11, 2.5, 14, corner: 1.2), SceneColor(0xFFFFFF, opacity: 0.35)),
                SceneElement(ScenePath.group([ScenePath.rect(p.x - 6, p.y + 6, 12, 3.5, corner: 1), ScenePath.rect(p.x - 6, p.y + 28.5, 12, 3.5, corner: 1)]), gold),
                SceneElement(ScenePath.line([(p.x, p.y + 32), (p.x, p.y + 40)]), gold, lineWidth: 1.2)
            ])
        }
        var lights: [SceneLight] = []
        for (y, count) in [(CGFloat(250), 9), (350, 10), (450, 9)] {
            let start = CGPoint(x: -10, y: y), end = CGPoint(x: 400, y: y - 10), control = CGPoint(x: 195, y: y + 60)
            background.append(SceneElement(ScenePath.curve(from: start, to: end, control: control), SceneColor(0x8C7AA8), lineWidth: 1.2))
            for index in 0..<count {
                let point = ScenePath.point(onCurveFrom: start, to: end, control: control, at: (CGFloat(index) + 0.5) / CGFloat(count))
                background.append(SceneElement(ScenePath.line([(point.x, point.y), (point.x, point.y + 7)]), SceneColor(0x8C7AA8), lineWidth: 1))
                lights.append(lantern(point))
            }
        }
        // 29 February: a lantern under the eaves of the first house.
        lights.append(lantern(CGPoint(x: 95, y: 596)))
        let windows = [(CGFloat(40), CGFloat(628), CGFloat(32), CGFloat(26)), (118, 628, 32, 26), (232, 620, 36, 30), (318, 620, 36, 30)]
        let lattice = ScenePath.group(windows.flatMap { x, y, w, h in
            [ScenePath.line([(x + w / 2, y), (x + w / 2, y + h)]), ScenePath.line([(x, y + h / 2), (x + w, y + h / 2)]), ScenePath.rect(x, y, w, h)]
        })
        let completion: [SceneElement] = [
            SceneElement(ScenePath.circle(300, 160, 28), SceneColor(0xFFF3C4), glow: 18),
            SceneElement(ScenePath.curve(from: CGPoint(x: 95, y: 190), to: CGPoint(x: 150, y: 560), control: CGPoint(x: 60, y: 420)), SceneColor(0xF7F1E3, opacity: 0.5), lineWidth: 0.8),
            SceneElement(ScenePath.rect(80, 150, 30, 40, corner: 2), SceneColor(0xF7F1E3)),
            SceneElement(ScenePath.rect(80, 150, 30, 7), SceneColor(0xE8505B)),
            SceneElement(ScenePath.circle(95, 172, 6), SceneColor(0x3A2A63)),
            SceneElement(ScenePath.group([ScenePath.line([(80, 150), (110, 190)]), ScenePath.line([(110, 150), (80, 190)])]), SceneColor(0x4F7DF5, opacity: 0.6), lineWidth: 1),
            SceneElement(ScenePath.group(windows.map { ScenePath.rect($0.0, $0.1, $0.2, $0.3) }), SceneColor(0xFFCF7A), glow: 10),
            SceneElement(lattice, SceneColor(0x9C6A2A), lineWidth: 1.2)
        ]
        return JourneyScene(month: 2, title: "설날 청사초롱", sky: [SceneColor(0x1C1440), SceneColor(0x4B2E6B), SceneColor(0xC9738A)],
                            background: background, lights: lights, completion: completion, ambience: ambience(for: 2))
    }()

    // MARK: 3월 · 봄 들판 — buds bloom into flowers; when full, a rainbow and butterflies

    static let springMeadow: JourneyScene = {
        let points = scatter(count: 31, seed: 303, x: 16...374, y: 582...688, minimumDistance: 24)
        let colors = [SceneColor(0xFFD95A), SceneColor(0xFF9EB5), SceneColor(0xFFFFFF), SceneColor(0xC9A6FF)]
        let stems = ScenePath.group(points.map { ScenePath.line([($0.x, $0.y), ($0.x, $0.y + 12)]) })
        let leaves = ScenePath.group(points.enumerated().map { index, point in
            ScenePath.petal(from: CGPoint(x: point.x, y: point.y + 10), length: 7, width: 2.5, angle: index.isMultiple(of: 2) ? -0.6 : -.pi + 0.6)
        })
        let lights = points.enumerated().map { index, point -> SceneLight in
            let color = colors[index % colors.count]
            let center = color == SceneColor(0xFFD95A) ? SceneColor(0xE8781A) : SceneColor(0xFFB020)
            return SceneLight(ScenePath.blossom(point.x, point.y, radius: 6.5, rotation: CGFloat(index) * 0.4), on: color, off: SceneColor(0x3F7D3A),
                              offPath: ScenePath.ellipse(point.x - 3, point.y - 5, 6, 9), glow: 3,
                              accents: [SceneElement(ScenePath.circle(point.x, point.y, 2.3), center)])
        }
        let rainbowColors: [UInt32] = [0xFF6B6B, 0xFFA94D, 0xFFE066, 0x69DB7C, 0x4DABF7, 0x9775FA]
        let rainbow = rainbowColors.enumerated().map { index, hex in
            SceneElement(ScenePath.arc(195, 600, radius: 250 - CGFloat(index) * 8, from: .pi, to: 2 * .pi), SceneColor(hex, opacity: 0.4), lineWidth: 8)
        }
        func butterfly(_ x: CGFloat, _ y: CGFloat, _ hex: UInt32) -> [SceneElement] {
            [SceneElement(ScenePath.group([ScenePath.ellipse(center: CGPoint(x: x - 5, y: y - 3), width: 10, height: 8, angle: -0.5),
                                           ScenePath.ellipse(center: CGPoint(x: x + 5, y: y - 3), width: 10, height: 8, angle: 0.5),
                                           ScenePath.ellipse(center: CGPoint(x: x - 4, y: y + 4), width: 6, height: 5, angle: 0.4),
                                           ScenePath.ellipse(center: CGPoint(x: x + 4, y: y + 4), width: 6, height: 5, angle: -0.4)]), SceneColor(hex), still: true),
             SceneElement(ScenePath.line([(x, y - 6), (x, y + 7)]), SceneColor(0x3B2A20), lineWidth: 1.4, still: true)]
        }
        let rays = ScenePath.group((0..<12).map { index -> CGPath in
            let angle = CGFloat(index) * .pi / 6
            return ScenePath.line([(80 + cos(angle) * 33, 300 + sin(angle) * 33), (80 + cos(angle) * 45, 300 + sin(angle) * 45)])
        })
        return JourneyScene(
            month: 3, title: "봄 들판", sky: [SceneColor(0x2E5E8C), SceneColor(0x6FA8C4), SceneColor(0xCFE8C0)],
            background: [
                SceneElement(ScenePath.circle(80, 300, 26), SceneColor(0xFFF4C9, opacity: 0.95), glow: 10),
                SceneElement(ScenePath.group([ScenePath.ellipse(220, 232, 96, 26), ScenePath.ellipse(250, 214, 58, 32)]), SceneColor(0xFFFFFF, opacity: 0.7)),
                SceneElement(ScenePath.ellipse(-120, 540, 420, 260), SceneColor(0x8CC26F)),
                SceneElement(ScenePath.ellipse(140, 555, 400, 240), SceneColor(0x74B060)),
                SceneElement(ScenePath.ellipse(-50, 596, 490, 180), SceneColor(0x5E9A50)),
                SceneElement(ScenePath.rect(0, 650, 390, 50), SceneColor(0x5E9A50)),
                SceneElement(stems, SceneColor(0x3F7D3A), lineWidth: 1.5),
                SceneElement(leaves, SceneColor(0x4E9447))
            ],
            lights: lights,
            completion: rainbow + [SceneElement(rays, SceneColor(0xFFF4C9, opacity: 0.85), lineWidth: 2)]
                + butterfly(118, 480, 0xFFD43B) + butterfly(272, 452, 0xFF8FAB) + butterfly(330, 520, 0x9BE7FF),
            ambience: ambience(for: 3)
        )
    }()

    // MARK: 4월 · 벚꽃나무 — five-petal blossoms open from the middle outward; when full, a petal carpet and moon

    static let cherryBlossom: JourneyScene = {
        var random = SceneRandom(seed: 404)
        let petals = ScenePath.group((0..<14).map { _ in
            ScenePath.ellipse(center: CGPoint(x: random.next(10...380), y: random.next(520...690)), width: 5, height: 3.4, angle: random.next(0...3))
        })
        let colors = [SceneColor(0xFFC4D6), SceneColor(0xFFE1EA), SceneColor(0xFF9DBA)]
        let lights = sunflower(count: 30, center: CGPoint(x: 195, y: 420), radiusX: 150, radiusY: 105).enumerated().map { index, point -> SceneLight in
            let blossoms = [(point.x, point.y, CGFloat(11.5)), (point.x - 11, point.y + 7, CGFloat(7.5)), (point.x + 11, point.y + 6, CGFloat(7.5))]
            let rotation = CGFloat(index) * 0.7
            return SceneLight(ScenePath.group(blossoms.map { ScenePath.blossom($0.0, $0.1, radius: $0.2, rotation: rotation) }),
                              on: colors[index % colors.count], off: SceneColor(0x6B4A66), offPath: ScenePath.circle(point.x, point.y, 5), glow: 5,
                              accents: [SceneElement(ScenePath.group(blossoms.map { ScenePath.circle($0.0, $0.1, $0.2 * 0.22) }), SceneColor(0xD6457A))])
        }
        var falling = SceneRandom(seed: 414)
        let fallingPetals = ScenePath.group((0..<24).map { _ in
            ScenePath.ellipse(center: CGPoint(x: falling.next(10...380), y: falling.next(300...640)), width: 5.5, height: 3.6, angle: falling.next(0...3))
        })
        let carpet = ScenePath.group((0..<40).map { _ in
            ScenePath.ellipse(center: CGPoint(x: falling.next(0...390), y: falling.next(652...698)), width: 6, height: 3.5, angle: falling.next(0...3))
        })
        return JourneyScene(
            month: 4, title: "벚꽃나무", sky: [SceneColor(0x3A2552), SceneColor(0x9E5A8A), SceneColor(0xF0B3C4)],
            background: [SceneElement(ScenePath.ellipse(-80, 630, 550, 160), SceneColor(0x5A3A5C)),
                         SceneElement(ScenePath.rect(0, 670, 390, 30), SceneColor(0x5A3A5C))]
                + tree(color: SceneColor(0x4A2C3A))
                + [SceneElement(petals, SceneColor(0xFFC4D6, opacity: 0.7), still: true)],
            lights: lights,
            completion: [
                SceneElement(ScenePath.circle(76, 190, 22), SceneColor(0xFFF1F4), glow: 16),
                SceneElement(ScenePath.ellipse(-40, 660, 470, 44), SceneColor(0xFFC4D6, opacity: 0.55)),
                SceneElement(carpet, SceneColor(0xFFD9E4)),
                SceneElement(fallingPetals, SceneColor(0xFFD1DF, opacity: 0.95), still: true)
            ],
            ambience: ambience(for: 4)
        )
    }()

    // MARK: 5월 · 연등 — lotus lanterns over a temple; when full, the temple glows under the moon

    static let lotusLanterns: JourneyScene = {
        let colors = [SceneColor(0xFF8FB1), SceneColor(0xFFD66B), SceneColor(0x8EE3A1), SceneColor(0xFFA86B), SceneColor(0xC69CFF)]
        var background: [SceneElement] = [
            SceneElement(ScenePath.rect(60, 604, 270, 96), SceneColor(0x15183A)),
            SceneElement(ScenePath.polygon([(20, 612), (50, 596), (80, 562), (310, 562), (340, 596), (370, 612), (330, 604), (60, 604)]), SceneColor(0x0E1029)),
            SceneElement(ScenePath.rect(130, 530, 130, 34), SceneColor(0x15183A)),
            SceneElement(ScenePath.polygon([(106, 538), (130, 518), (260, 518), (284, 538)]), SceneColor(0x0E1029)),
            SceneElement(ScenePath.rect(170, 640, 50, 60, corner: 3), SceneColor(0x2A2F5A))
        ]
        var lights: [SceneLight] = []
        for (row, (y, count)) in [(CGFloat(240), 8), (320, 8), (400, 8), (480, 7)].enumerated() {
            background.append(SceneElement(ScenePath.line([(-5, y), (395, y)]), SceneColor(0x6A6F9E), lineWidth: 1.2))
            for index in 0..<count {
                let x = 390 * (CGFloat(index) + 0.5) / CGFloat(count)
                let base = CGPoint(x: x, y: y + 26)
                let outer: [(CGFloat, CGFloat, CGFloat)] = [(-160, 14, 5.5), (-125, 19, 6.5), (-90, 21, 7), (-55, 19, 6.5), (-20, 14, 5.5)]
                let lotus = ScenePath.group(outer.map { ScenePath.petal(from: base, length: $0.1, width: $0.2, angle: $0.0 * .pi / 180) }
                                            + [ScenePath.ellipse(x - 10, y + 20, 20, 9)])
                let inner = ScenePath.group([-115, -90, -65].map { ScenePath.petal(from: base, length: 13, width: 4, angle: CGFloat($0) * .pi / 180) })
                lights.append(SceneLight(lotus, on: colors[(index + row * 2) % colors.count], off: SceneColor(0x262A55), glow: 9, accents: [
                    SceneElement(inner, SceneColor(0xFFFFFF, opacity: 0.45)),
                    SceneElement(ScenePath.ellipse(x - 12, y + 25, 24, 6), SceneColor(0x5FBF73)),
                    SceneElement(ScenePath.line([(x, y + 31), (x, y + 38)]), SceneColor(0xF2C14E), lineWidth: 1.2)
                ]))
            }
        }
        var random = SceneRandom(seed: 515)
        let sparkles = ScenePath.group((0..<14).map { _ in
            ScenePath.star(random.next(10...380), random.next(90...220), outer: random.next(3...5), inner: 1, points: 4)
        })
        return JourneyScene(
            month: 5, title: "연등", sky: [SceneColor(0x0D1233), SceneColor(0x1F2A5C), SceneColor(0x3B3D7A)],
            background: background, lights: lights,
            completion: [
                SceneElement(ScenePath.circle(322, 150, 22), SceneColor(0xFFF4D6), glow: 16),
                SceneElement(sparkles, SceneColor(0xFFFFFF, opacity: 0.85), glow: 4, still: true),
                SceneElement(ScenePath.group([ScenePath.rect(92, 628, 40, 26, corner: 2), ScenePath.rect(258, 628, 40, 26, corner: 2), ScenePath.rect(150, 538, 90, 18, corner: 2)]),
                             SceneColor(0xFFCF7A), glow: 10),
                SceneElement(ScenePath.rect(170, 640, 50, 60, corner: 3), SceneColor(0xFFB65C), glow: 14)
            ],
            ambience: ambience(for: 5)
        )
    }()

    // MARK: 6월 · 반딧불이 숲 — fireflies gather; when full, a moonlit pond and a swarm of fireflies

    static let fireflyForest: JourneyScene = {
        var random = SceneRandom(seed: 606)
        var background: [SceneElement] = [
            SceneElement(ScenePath.circle(310, 200, 34), SceneColor(0xF3F0D0, opacity: 0.08)),
            SceneElement(ScenePath.circle(310, 200, 17), SceneColor(0xF3F0D0, opacity: 0.9), glow: 8)
        ]
        let backTrees = stride(from: CGFloat(-10), through: 400, by: 42).map { x -> CGPath in
            let tip = random.next(470...525)
            return ScenePath.polygon([(x, tip), (x - 30, 650), (x + 30, 650)])
        }
        let frontTrees = [CGFloat(-10), 72, 158, 246, 330, 408].map { x -> CGPath in
            let tip = random.next(520...565)
            return ScenePath.polygon([(x, tip), (x - 44, 700), (x + 44, 700)])
        }
        background.append(SceneElement(ScenePath.group(backTrees), SceneColor(0x0F3A2D)))
        background.append(SceneElement(ScenePath.group(frontTrees), SceneColor(0x06201A)))
        let lights = scatter(count: 30, seed: 616, x: 12...378, y: 300...640, minimumDistance: 30).map { point in
            SceneLight(ScenePath.circle(point.x, point.y, 3.2), on: SceneColor(0xE9FF8C), off: SceneColor(0x1D4A3B),
                       offPath: ScenePath.circle(point.x, point.y, 1.5), glow: 11,
                       accents: [SceneElement(ScenePath.circle(point.x, point.y, 1.4), SceneColor(0xFFFFFF))])
        }
        var swarm = SceneRandom(seed: 626)
        let smallFlies = ScenePath.group((0..<40).map { _ in ScenePath.circle(swarm.next(5...385), swarm.next(260...650), swarm.next(1...1.8)) })
        let grass = ScenePath.group((0..<46).map { index -> CGPath in
            let x = CGFloat(index) * 8.6 + swarm.next(-2...2)
            let height = swarm.next(10...22)
            return ScenePath.polygon([(x - 2, 700), (x + swarm.next(-4...4), 700 - height), (x + 2, 700)])
        })
        return JourneyScene(
            month: 6, title: "반딧불이 숲", sky: [SceneColor(0x03110D), SceneColor(0x0A2A21), SceneColor(0x174537)],
            background: background, lights: lights,
            completion: [
                SceneElement(ScenePath.circle(310, 200, 46), SceneColor(0xF3F0D0, opacity: 0.1), glow: 20),
                SceneElement(ScenePath.ellipse(20, 652, 180, 30), SceneColor(0x0D3444)),
                SceneElement(ScenePath.ellipse(96, 660, 30, 5), SceneColor(0xF3F0D0, opacity: 0.45)),
                SceneElement(smallFlies, SceneColor(0xE9FF8C, opacity: 0.75), glow: 5, still: true),
                SceneElement(grass, SceneColor(0x041510))
            ],
            ambience: ambience(for: 6)
        )
    }()

    // MARK: 7월 · 여름 바다 — stars come out; when full, the Milky Way, a shooting star and a sailboat

    static let summerSea: JourneyScene = {
        let reflection = ScenePath.group([ScenePath.ellipse(62, 574, 36, 3), ScenePath.ellipse(68, 594, 24, 3), ScenePath.ellipse(72, 616, 16, 3), ScenePath.ellipse(76, 640, 9, 2)])
        let background: [SceneElement] = [
            SceneElement(ScenePath.circle(80, 230, 24), SceneColor(0xF8F4DC), glow: 12),
            SceneElement(ScenePath.rect(0, 560, 390, 140), SceneColor(0x0A2342)),
            SceneElement(reflection, SceneColor(0xF8F4DC, opacity: 0.35)),
            SceneElement(ScenePath.polygon([(330, 463), (190, 425), (190, 480)]), SceneColor(0xFFF2A8, opacity: 0.12)),
            SceneElement(ScenePath.polygon([(262, 700), (270, 600), (300, 570), (360, 564), (390, 580), (390, 700)]), SceneColor(0x07152C)),
            SceneElement(ScenePath.polygon([(318, 568), (322, 470), (338, 470), (342, 568)]), SceneColor(0xE8E6F0)),
            SceneElement(ScenePath.group([ScenePath.rect(320, 500, 20, 10), ScenePath.rect(319, 530, 22, 10)]), SceneColor(0xD9534F)),
            SceneElement(ScenePath.rect(316, 455, 28, 16), SceneColor(0x2A2F4A)),
            SceneElement(ScenePath.polygon([(314, 455), (330, 440), (346, 455)]), SceneColor(0xD9534F)),
            SceneElement(ScenePath.circle(330, 463, 5), SceneColor(0xFFF2A8), glow: 6)
        ]
        let points = scatter(count: 31, seed: 707, x: 12...378, y: 110...520, minimumDistance: 38) { point in
            hypot(point.x - 80, point.y - 230) > 44 && !(point.x > 296 && point.y > 424)
        }
        var random = SceneRandom(seed: 717)
        let lights = points.map { point -> SceneLight in
            let size = random.next(5.5...8.5)
            return SceneLight(ScenePath.star(point.x, point.y, outer: size, inner: size * 0.45, points: 5, rotation: -.pi / 2 + random.next(-0.3...0.3)),
                              on: SceneColor(0xFFF3B0), off: SceneColor(0x2A3D6E), offPath: ScenePath.circle(point.x, point.y, 1.3), glow: 7,
                              accents: [SceneElement(ScenePath.circle(point.x, point.y, size * 0.22), SceneColor(0xFFFFFF))])
        }
        var dust = SceneRandom(seed: 727)
        let milkyDots = ScenePath.group((0..<70).map { _ -> CGPath in
            let t = dust.next()
            return ScenePath.circle(-20 + t * 430 + dust.next(-15...15), 330 - t * 210 + dust.next(-30...30), dust.next(0.6...1.3))
        })
        return JourneyScene(
            month: 7, title: "여름 바다", sky: [SceneColor(0x020617), SceneColor(0x0B1F4A), SceneColor(0x1E4478)],
            background: background, lights: lights,
            completion: [
                SceneElement(ScenePath.band(from: CGPoint(x: -20, y: 300), to: CGPoint(x: 410, y: 95), bend: -30, thickness: 62), SceneColor(0xC9D6FF, opacity: 0.1), glow: 22),
                SceneElement(milkyDots, SceneColor(0xFFFFFF, opacity: 0.6)),
                SceneElement(ScenePath.polygon([(160, 176), (58, 120), (55, 126)]), SceneColor(0xFFFFFF, opacity: 0.85), glow: 6, still: true),
                SceneElement(ScenePath.circle(160, 176, 2.4), SceneColor(0xFFFFFF), glow: 6, still: true),
                SceneElement(ScenePath.polygon([(330, 463), (160, 405), (160, 510)]), SceneColor(0xFFF2A8, opacity: 0.2)),
                SceneElement(ScenePath.polygon([(165, 538), (165, 584), (138, 584)]), SceneColor(0xE8E6F0, opacity: 0.95)),
                SceneElement(ScenePath.polygon([(169, 548), (169, 584), (188, 584)]), SceneColor(0xE8E6F0, opacity: 0.8)),
                SceneElement(ScenePath.polygon([(134, 587), (194, 587), (184, 598), (144, 598)]), SceneColor(0x07152C)),
                SceneElement(ScenePath.circle(167, 535, 2), SceneColor(0xFFD27A), glow: 6)
            ],
            ambience: ambience(for: 7)
        )
    }()

    // MARK: 8월 · 불꽃놀이 — fireworks burst; when full, a grand finale over a lit city

    static let fireworks: JourneyScene = {
        let widths: [CGFloat] = [40, 30, 50, 25, 45, 35, 60, 30, 40, 35]
        let heights: [CGFloat] = [70, 110, 60, 140, 90, 75, 120, 55, 100, 80]
        var x: CGFloat = 0
        var skyline: [CGPath] = []
        var cityWindows: [CGPath] = []
        var windowRandom = SceneRandom(seed: 828)
        for (width, height) in zip(widths, heights) {
            skyline.append(ScenePath.rect(x, 640 - height, width + 1, height))
            var y = 640 - height + 8
            while y < 628 {
                var column = x + 6
                while column < x + width - 8 {
                    if windowRandom.next() > 0.55 { cityWindows.append(ScenePath.rect(column, y, 4, 6)) }
                    column += 9
                }
                y += 12
            }
            x += width
        }
        let colors = [SceneColor(0xFF6B6B), SceneColor(0xFFD93D), SceneColor(0x6BCBFF), SceneColor(0xB388FF), SceneColor(0x7CFFB2), SceneColor(0xFF9F68)]
        var random = SceneRandom(seed: 818)
        func burst(_ center: CGPoint, radius: CGFloat, rays: Int) -> (rays: CGPath, tips: CGPath) {
            let angles = (0..<rays).map { CGFloat($0) * 2 * .pi / CGFloat(rays) }
            let lines = angles.map { angle in
                ScenePath.line([(center.x + cos(angle) * radius * 0.35, center.y + sin(angle) * radius * 0.35),
                                (center.x + cos(angle) * radius, center.y + sin(angle) * radius)])
            }
            let tips = angles.map { ScenePath.circle(center.x + cos($0) * radius * 1.12, center.y + sin($0) * radius * 1.12, 1.6) }
            return (ScenePath.group(lines), ScenePath.group(tips))
        }
        let lights = scatter(count: 31, seed: 808, x: 30...360, y: 120...460, minimumDistance: 44).enumerated().map { index, point -> SceneLight in
            let parts = burst(point, radius: random.next(14...24), rays: 12)
            let color = colors[index % colors.count]
            return SceneLight(parts.rays, on: color, off: SceneColor(0x2E2560), offPath: ScenePath.circle(point.x, point.y, 1), glow: 8, lineWidth: 2,
                              accents: [SceneElement(parts.tips, color), SceneElement(ScenePath.circle(point.x, point.y, 2), SceneColor(0xFFFFFF))])
        }
        let finale = burst(CGPoint(x: 195, y: 215), radius: 62, rays: 24)
        let finaleInner = burst(CGPoint(x: 195, y: 215), radius: 32, rays: 12)
        let reflections = ScenePath.group((0..<10).map { index in
            ScenePath.rect(20 + CGFloat(index) * 36 + windowRandom.next(-6...6), 648 + windowRandom.next(0...10), 3, windowRandom.next(14...34), corner: 1.5)
        })
        return JourneyScene(
            month: 8, title: "불꽃놀이", sky: [SceneColor(0x07071C), SceneColor(0x17123F), SceneColor(0x33205A)],
            background: [SceneElement(ScenePath.group(skyline), SceneColor(0x0B0A1F)),
                         SceneElement(ScenePath.rect(0, 640, 390, 60), SceneColor(0x0E1030)),
                         SceneElement(ScenePath.line([(0, 612), (390, 612)]), SceneColor(0x1B1840), lineWidth: 4)],
            lights: lights,
            completion: [
                SceneElement(finale.rays, SceneColor(0xFFE08A), lineWidth: 2.2, glow: 12, still: true),
                SceneElement(finale.tips, SceneColor(0xFFF6D5), glow: 6, still: true),
                SceneElement(finaleInner.rays, SceneColor(0xFF9FD0), lineWidth: 1.8, glow: 8, still: true),
                SceneElement(ScenePath.group(cityWindows), SceneColor(0xFFD27A, opacity: 0.9)),
                SceneElement(reflections, SceneColor(0xFFC46B, opacity: 0.35))
            ],
            ambience: ambience(for: 8)
        )
    }()

    // MARK: 9월 · 한가위 풍등 — sky lanterns rise; when full, the moon rabbit and a lit village

    static let harvestMoon: JourneyScene = {
        let houseSpots: [(CGFloat, CGFloat)] = [(14, 72), (116, 80), (224, 68), (306, 76)]
        let roofs = ScenePath.group(houseSpots.map { x, width in
            ScenePath.polygon([(x - 12, 646), (x, 632), (x + width * 0.15, 620), (x + width * 0.85, 620), (x + width, 632), (x + width + 12, 646)])
        })
        let houses = ScenePath.group(houseSpots.map { x, width in ScenePath.rect(x, 644, width, 56) })
        let points = scatter(count: 30, seed: 909, x: 20...370, y: 190...600, minimumDistance: 34) { point in
            hypot(point.x - 290, point.y - 200) > 72
        }.sorted { $0.y > $1.y }
        let lights = points.map { point -> SceneLight in
            let s = 0.6 + 0.6 * (point.y - 190) / 410
            let x = point.x, y = point.y
            let ribs = ScenePath.group([ScenePath.line([(x - 2 * s, y - 9 * s), (x - 3 * s, y + 9 * s)]), ScenePath.line([(x + 2 * s, y - 9 * s), (x + 3 * s, y + 9 * s)])])
            return SceneLight(ScenePath.polygon([(x - 5 * s, y - 9 * s), (x + 5 * s, y - 9 * s), (x + 7 * s, y + 9 * s), (x - 7 * s, y + 9 * s)]),
                              on: SceneColor(0xFFB65C), off: SceneColor(0x33305E), glow: 10, accents: [
                                SceneElement(ribs, SceneColor(0xE0882E, opacity: 0.6), lineWidth: 0.7),
                                SceneElement(ScenePath.line([(x - 5 * s, y - 9 * s), (x + 5 * s, y - 9 * s)]), SceneColor(0xC9711F), lineWidth: 1.2),
                                SceneElement(ScenePath.ellipse(center: CGPoint(x: x, y: y + 6 * s), width: 3.5 * s, height: 5 * s, angle: 0), SceneColor(0xFFF3C4))
                              ])
        }
        let villageWindows = ScenePath.group(houseSpots.flatMap { x, width in
            [ScenePath.rect(x + width * 0.2, 660, 12, 12), ScenePath.rect(x + width * 0.62, 660, 12, 12)]
        })
        var far = SceneRandom(seed: 919)
        let farLanterns = ScenePath.group((0..<24).map { _ in ScenePath.rect(far.next(10...380), far.next(110...330), 2.5, 3.5) })
        return JourneyScene(
            month: 9, title: "한가위 풍등", sky: [SceneColor(0x10183A), SceneColor(0x2B2D63), SceneColor(0x74507E)],
            background: [
                SceneElement(ScenePath.circle(290, 200, 70), SceneColor(0xFFF1C1, opacity: 0.12)),
                SceneElement(ScenePath.circle(290, 200, 48), SceneColor(0xFFF1C1), glow: 14),
                SceneElement(ScenePath.ellipse(-100, 596, 380, 200), SceneColor(0x1E1C3E)),
                SceneElement(ScenePath.ellipse(160, 590, 360, 220), SceneColor(0x1A1836)),
                SceneElement(houses, SceneColor(0x1A1633)),
                SceneElement(roofs, SceneColor(0x120F28))
            ],
            lights: lights,
            completion: [
                // The rabbit pounding rice cakes on the moon.
                SceneElement(ScenePath.group([ScenePath.ellipse(266, 198, 24, 18), ScenePath.circle(292, 196, 8),
                                              ScenePath.ellipse(center: CGPoint(x: 290, y: 182), width: 4.5, height: 14, angle: -0.25),
                                              ScenePath.ellipse(center: CGPoint(x: 296, y: 183), width: 4.5, height: 14, angle: 0.2),
                                              ScenePath.rect(300, 210, 14, 10, corner: 2), ScenePath.polygon([(297, 200), (312, 190), (314, 192), (299, 202)])]),
                             SceneColor(0xE3CC8F)),
                SceneElement(villageWindows, SceneColor(0xFFCF7A), glow: 8),
                SceneElement(farLanterns, SceneColor(0xFFB65C, opacity: 0.7), glow: 3, still: true)
            ],
            ambience: ambience(for: 9)
        )
    }()

    // MARK: 10월 · 단풍 — maple leaves turn red from the edge inward; when full, leaves fall and cover the ground

    static let autumnMaple: JourneyScene = {
        let colors = [SceneColor(0xE8452C), SceneColor(0xF28C28), SceneColor(0xF6C343), SceneColor(0xC2362B)]
        var random = SceneRandom(seed: 1010)
        func leaf(_ x: CGFloat, _ y: CGFloat, size: CGFloat, rotation: CGFloat) -> (shape: CGPath, veins: CGPath) {
            func point(_ px: CGFloat, _ py: CGFloat) -> (CGFloat, CGFloat) {
                (x + (px * cos(rotation) - py * sin(rotation)) * size, y + (px * sin(rotation) + py * cos(rotation)) * size)
            }
            let base = point(0, 0.42)
            let veins = ScenePath.group([(0, -0.9), (0.85, -0.1), (-0.85, -0.1), (0.62, -0.55), (-0.62, -0.55), (0, 0.9)].map { tip in
                ScenePath.line([base, point(tip.0, tip.1)])
            })
            return (ScenePath.outline(ScenePath.mapleLeaf, x, y, size: size, rotation: rotation), veins)
        }
        let points = Array(sunflower(count: 31, center: CGPoint(x: 195, y: 420), radiusX: 150, radiusY: 110).reversed())
        let lights = points.enumerated().map { index, point -> SceneLight in
            let parts = leaf(point.x, point.y, size: 14, rotation: random.next(-0.5...0.5))
            return SceneLight(parts.shape, on: colors[index % colors.count], off: SceneColor(0x4E6B3A), glow: 2,
                              accents: [SceneElement(parts.veins, SceneColor(0x7A1C10, opacity: 0.55), lineWidth: 0.8)])
        }
        let fallen = ScenePath.group((0..<10).map { _ in leaf(random.next(20...370), random.next(672...694), size: 6, rotation: random.next(0...6)).shape })
        let fallingLeaves = ScenePath.group((0..<14).map { _ in leaf(random.next(20...370), random.next(470...650), size: random.next(6...9), rotation: random.next(0...6)).shape })
        let carpetRed = ScenePath.group((0..<26).map { _ in leaf(random.next(0...390), random.next(662...698), size: 7, rotation: random.next(0...6)).shape })
        let carpetYellow = ScenePath.group((0..<20).map { _ in leaf(random.next(0...390), random.next(662...698), size: 6, rotation: random.next(0...6)).shape })
        let birds = ScenePath.group([(CGFloat(78), CGFloat(232)), (104, 216), (96, 252), (124, 238)].map { x, y in
            ScenePath.line([(x - 7, y - 3), (x, y), (x + 7, y - 3)])
        })
        return JourneyScene(
            month: 10, title: "단풍", sky: [SceneColor(0x2A1A3D), SceneColor(0x9A4E3E), SceneColor(0xF0A65A)],
            background: [SceneElement(ScenePath.circle(300, 590, 40), SceneColor(0xFFD28A, opacity: 0.8)),
                         SceneElement(ScenePath.ellipse(-80, 600, 300, 200), SceneColor(0x6B3A2E)),
                         SceneElement(ScenePath.ellipse(180, 610, 320, 200), SceneColor(0x5A2F26)),
                         SceneElement(ScenePath.rect(0, 660, 390, 40), SceneColor(0x4A261F))]
                + tree(color: SceneColor(0x3B2320))
                + [SceneElement(fallen, SceneColor(0xE8452C, opacity: 0.85))],
            lights: lights,
            completion: [
                SceneElement(carpetRed, SceneColor(0xD9432A)),
                SceneElement(carpetYellow, SceneColor(0xF2B233)),
                SceneElement(fallingLeaves, SceneColor(0xF28C28, opacity: 0.95), still: true),
                SceneElement(birds, SceneColor(0x2A1A3D, opacity: 0.75), lineWidth: 1.6, still: true)
            ],
            ambience: ambience(for: 10)
        )
    }()

    // MARK: 11월 · 도시의 밤 — the original apartment windows; when full, the whole city lights up under the moon

    static let cityNight: JourneyScene = {
        let w = JourneyScene.canvas.width, h = JourneyScene.canvas.height
        func shape(_ fractions: [(CGFloat, CGFloat)]) -> CGPath { ScenePath.polygon(fractions.map { ($0.0 * w, $0.1 * h) }) }
        // Same outlines as BuildingView.drawBackBuilding/drawBuilding.
        let back = ScenePath.group([
            shape([(0.01, 1), (0.01, 0.55), (0.04, 0.55), (0.04, 0.5), (0.15, 0.5), (0.15, 1)]),
            shape([(0.18, 1), (0.18, 0.55), (0.3, 0.55), (0.35, 0.6), (0.35, 1)]),
            shape([(0.355, 1), (0.355, 0.63), (0.45, 0.63), (0.45, 0.66), (0.5, 0.66), (0.5, 1)]),
            shape([(0.5, 1), (0.5, 0.85), (0.671, 0.85), (0.671, 0.65), (0.8, 0.55), (0.8, 1)]),
            shape([(0.8, 1), (0.8, 0.55), (0.94, 0.55), (0.94, 0.48), (1, 0.48), (1, 1)])
        ])
        let front = ScenePath.group([
            shape([(0, 1), (0, 0.65), (0.0875, 0.65), (0.0875, 0.7), (0.14, 0.7), (0.14, 1)]),
            shape([(0.1575, 1), (0.1575, 0.75), (0.245, 0.65), (0.38, 0.65), (0.38, 0.7), (0.42, 0.7), (0.42, 1)]),
            shape([(0.455, 1), (0.455, 0.8), (0.525, 0.8), (0.525, 0.75), (0.665, 0.75), (0.665, 1)]),
            shape([(0.68, 1), (0.68, 0.6), (0.9, 0.6), (0.9, 0.65), (0.98, 0.65), (0.98, 1)])
        ])
        // Same window placement and order as BuildingView + WindowDrawingHelper.
        let buildings: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, floors: [[Int]])] = [
            (0, 0.97, 0.07, 0.3, [[0, 1], [1, 1], [1], [1, 1], [1]]),
            (0.21, 0.99, 0.07, 0.31, [[0, 1, 1], [1, 0, 1], [1, 1], [0, 1]]),
            (0.51, 1.02, 0.048, 0.25, [[1, 1, 0], [0, 1, 1], [1, 0, 1], [0, 1]]),
            (0.73, 1.03, 0.08, 0.4, [[1], [1], [1, 1, 1], [1, 1]]),
            (0, 0.9, 0.045, 0.3, [[0, 1, 1]]),
            (0.94, 0.89, 0.045, 0.3, [[1]])
        ]
        var lights: [SceneLight] = []
        for building in buildings {
            for (floor, windows) in building.floors.enumerated() {
                for (index, columns) in windows.enumerated() where columns != 0 {
                    let windowWidth = building.width * w / CGFloat(columns)
                    let windowHeight = building.height * h / CGFloat(building.floors.count)
                    let x = building.x * w + windowWidth * CGFloat(index)
                    let y = building.y * h - windowHeight * CGFloat(floor + 1)
                    let frame = ScenePath.group([ScenePath.line([(x + 5, y), (x + 5, y + 22)]), ScenePath.line([(x, y + 11), (x + 10, y + 11)])])
                    lights.append(SceneLight(ScenePath.rect(x, y, 10, 22), on: SceneColor(0xFFEB4D), off: SceneColor(0x555555), glow: 4,
                                             accents: [SceneElement(frame, SceneColor(0xB89A10, opacity: 0.7), lineWidth: 0.8)]))
                }
            }
        }
        // Windows only where the back buildings show above the front ones.
        var random = SceneRandom(seed: 1111)
        let backAreas: [(ClosedRange<CGFloat>, ClosedRange<CGFloat>)] = [(8...48, 362...410), (74...128, 396...444), (166...190, 452...512), (318...380, 346...410)]
        var backWindows: [CGPath] = []
        for (xs, ys) in backAreas {
            for y in stride(from: ys.lowerBound, through: ys.upperBound, by: 16) {
                for x in stride(from: xs.lowerBound, through: xs.upperBound, by: 12) where random.next() > 0.45 {
                    backWindows.append(ScenePath.rect(x, y, 5, 8))
                }
            }
        }
        let stars = ScenePath.group((0..<22).map { _ in ScenePath.circle(random.next(10...380), random.next(90...300), random.next(0.8...1.6)) })
        return JourneyScene(
            month: 11, title: "도시의 밤", sky: [SceneColor(0x7D2493), SceneColor(0xB4419A), SceneColor(0xEA5DA2)],
            background: [SceneElement(back, SceneColor(0x555555)), SceneElement(front, SceneColor(0x000000))], lights: lights,
            completion: [
                SceneElement(ScenePath.circle(312, 150, 20), SceneColor(0xFFF4D6), glow: 16),
                SceneElement(stars, SceneColor(0xFFFFFF, opacity: 0.85), still: true),
                SceneElement(ScenePath.group(backWindows), SceneColor(0xFFE9A0, opacity: 0.85), glow: 3),
                SceneElement(ScenePath.group([ScenePath.line([(351, 420), (351, 398)]), ScenePath.line([(95, 455), (95, 436)])]), SceneColor(0x000000), lineWidth: 1.5),
                SceneElement(ScenePath.group([ScenePath.circle(351, 397, 2.4), ScenePath.circle(95, 435, 2.4)]), SceneColor(0xFF4D4D), glow: 6)
            ],
            ambience: ambience(for: 11)
        )
    }()

    // MARK: 12월 · 크리스마스트리 — bulbs light up and the star comes last; when full, presents and snowfall

    static let christmasTree: JourneyScene = {
        var random = SceneRandom(seed: 1212)
        let snow = ScenePath.group((0..<40).map { _ in ScenePath.circle(random.next(0...390), random.next(100...640), random.next(1...2)) })
        let tiers: [(tip: CGFloat, base: CGFloat, half: CGFloat, color: UInt32)] = [
            (490, 645, 120, 0x174A2F), (420, 560, 100, 0x1F5B3A), (350, 480, 80, 0x174A2F), (300, 400, 55, 0x1F5B3A)
        ]
        var background: [SceneElement] = [
            SceneElement(snow, SceneColor(0xFFFFFF, opacity: 0.7), still: true),
            SceneElement(ScenePath.group([ScenePath.rect(10, 606, 60, 50), ScenePath.polygon([(4, 608), (40, 580), (76, 608)]),
                                          ScenePath.rect(320, 612, 60, 44), ScenePath.polygon([(314, 614), (350, 588), (386, 614)])]), SceneColor(0x1A2447)),
            SceneElement(ScenePath.ellipse(-60, 640, 510, 140), SceneColor(0xE8EEF8)),
            SceneElement(ScenePath.rect(0, 672, 390, 28), SceneColor(0xE8EEF8)),
            SceneElement(ScenePath.rect(183, 640, 24, 40), SceneColor(0x4A2F24))
        ]
        background += tiers.map { SceneElement(ScenePath.polygon([(195, $0.tip), (195 - $0.half, $0.base), (195 + $0.half, $0.base)]), SceneColor($0.color)) }
        let colors = [SceneColor(0xFF5A5F), SceneColor(0xFFD95A), SceneColor(0x5AC8FA), SceneColor(0x7CFF8A), SceneColor(0xFF9FF3)]
        var lights: [SceneLight] = []
        for (y, half, count) in [(CGFloat(385), CGFloat(38), 3), (440, 45, 4), (505, 50, 5), (545, 75, 5), (600, 72, 6), (635, 95, 7)] {
            let points = (0..<count).map { index -> CGPoint in
                let x = count == 1 ? 195 : 195 - half + 2 * half * CGFloat(index) / CGFloat(count - 1)
                return CGPoint(x: x, y: y + (index.isMultiple(of: 2) ? -3 : 3))
            }
            background.append(SceneElement(ScenePath.line(points.map { ($0.x, $0.y) }), SceneColor(0xD9C27A, opacity: 0.5), lineWidth: 1))
            for point in points {
                lights.append(SceneLight(ScenePath.circle(point.x, point.y, 5.5), on: colors[lights.count % colors.count], off: SceneColor(0x0E3322), glow: 7, accents: [
                    SceneElement(ScenePath.rect(point.x - 2, point.y - 7.5, 4, 3, corner: 0.8), SceneColor(0xD9C27A)),
                    SceneElement(ScenePath.circle(point.x - 1.8, point.y - 1.8, 1.6), SceneColor(0xFFFFFF, opacity: 0.85))
                ]))
            }
        }
        lights.append(SceneLight(ScenePath.star(195, 290, outer: 17, inner: 7.5, points: 5), on: SceneColor(0xFFD95A), off: SceneColor(0x3A4A3A), glow: 14,
                                 accents: [SceneElement(ScenePath.star(195, 290, outer: 8, inner: 3.5, points: 5), SceneColor(0xFFF4C2))]))
        let gifts: [(CGFloat, CGFloat, CGFloat, CGFloat, UInt32)] = [(126, 664, 28, 24, 0xE8505B), (156, 672, 22, 16, 0x4DABF7), (212, 666, 28, 22, 0x51CF66), (242, 674, 20, 14, 0xF783AC)]
        let ribbons = ScenePath.group(gifts.flatMap { x, y, w, h, _ in
            [ScenePath.line([(x + w / 2, y), (x + w / 2, y + h)]), ScenePath.line([(x, y + h / 2), (x + w, y + h / 2)])]
        })
        let bows = ScenePath.group(gifts.flatMap { x, y, w, _, _ in
            [ScenePath.ellipse(center: CGPoint(x: x + w / 2 - 3.5, y: y - 2), width: 7, height: 4.5, angle: -0.4),
             ScenePath.ellipse(center: CGPoint(x: x + w / 2 + 3.5, y: y - 2), width: 7, height: 4.5, angle: 0.4)]
        })
        var flakes = SceneRandom(seed: 1222)
        let bigSnow = ScenePath.group((0..<30).map { _ in
            ScenePath.star(flakes.next(0...390), flakes.next(100...620), outer: flakes.next(2.5...4.5), inner: 1.1, points: 6)
        })
        return JourneyScene(
            month: 12, title: "크리스마스트리", sky: [SceneColor(0x0B1430), SceneColor(0x1D2B5A), SceneColor(0x3E4E86)],
            background: background, lights: lights,
            completion: [
                SceneElement(ScenePath.circle(195, 290, 30), SceneColor(0xFFE9A0, opacity: 0.06)),
                SceneElement(ScenePath.circle(195, 290, 21), SceneColor(0xFFE9A0, opacity: 0.1)),
                SceneElement(ScenePath.group([ScenePath.rect(26, 620, 12, 12), ScenePath.rect(44, 620, 12, 12), ScenePath.rect(336, 624, 12, 12), ScenePath.rect(354, 624, 12, 12)]),
                             SceneColor(0xFFD27A), glow: 8),
                SceneElement(bigSnow, SceneColor(0xFFFFFF, opacity: 0.9), still: true)
            ] + gifts.map { SceneElement(ScenePath.rect($0.0, $0.1, $0.2, $0.3, corner: 2), SceneColor($0.4)) } + [
                SceneElement(ribbons, SceneColor(0xFFD43B), lineWidth: 2.2),
                SceneElement(bows, SceneColor(0xFFD43B))
            ],
            ambience: ambience(for: 12),
            keepsLastLightLast: true
        )
    }()

    // MARK: - Layout helpers

    /// A trunk with branches reaching into the canopy used by the April and October trees.
    private static func tree(color: SceneColor) -> [SceneElement] {
        [
            SceneElement(ScenePath.polygon([(182, 700), (178, 600), (170, 540), (186, 520), (198, 540), (206, 600), (210, 700)]), color),
            SceneElement(ScenePath.group([ScenePath.line([(190, 540), (130, 470), (80, 430)]), ScenePath.line([(190, 540), (250, 470), (310, 440)])]), color, lineWidth: 10),
            SceneElement(ScenePath.line([(190, 530), (195, 440), (200, 370)]), color, lineWidth: 9),
            SceneElement(ScenePath.group([ScenePath.line([(130, 470), (120, 400)]), ScenePath.line([(250, 470), (270, 390)])]), color, lineWidth: 6),
            SceneElement(ScenePath.group([ScenePath.line([(195, 440), (150, 390)]), ScenePath.line([(195, 440), (240, 380)])]), color, lineWidth: 5)
        ]
    }

    /// Evenly spread points inside an ellipse, from the center outward.
    static func sunflower(count: Int, center: CGPoint, radiusX: CGFloat, radiusY: CGFloat) -> [CGPoint] {
        (0..<count).map { index in
            let distance = sqrt((CGFloat(index) + 0.5) / CGFloat(count))
            let angle = CGFloat(index) * 2.399963
            return CGPoint(x: center.x + radiusX * distance * cos(angle), y: center.y + radiusY * distance * sin(angle))
        }
    }

    /// Randomly placed points that keep a minimum distance from each other, in the order they were placed.
    static func scatter(count: Int, seed: UInt64, x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>, minimumDistance: CGFloat,
                        allowed: (CGPoint) -> Bool = { _ in true }) -> [CGPoint] {
        var random = SceneRandom(seed: seed)
        var points: [CGPoint] = []
        var distance = minimumDistance
        while points.count < count {
            for _ in 0..<2000 where points.count < count {
                let point = CGPoint(x: random.next(x), y: random.next(y))
                guard allowed(point), points.allSatisfy({ hypot($0.x - point.x, $0.y - point.y) >= distance }) else { continue }
                points.append(point)
            }
            // Loosen the spacing rather than place fewer lights than the month has days.
            distance *= 0.9
        }
        return points
    }
}
