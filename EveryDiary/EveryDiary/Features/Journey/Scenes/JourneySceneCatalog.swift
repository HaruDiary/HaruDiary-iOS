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
        let snowLight = SceneColor(0xF7F9FF), snowShade = SceneColor(0xC4CFE8)
        var background: [SceneElement] = SceneArt.stars(seed: 102, count: 110, area: CGRect(x: 0, y: 60, width: 390, height: 380))
            + SceneArt.moon(300, 180, radius: 26, light: SceneColor(0xFBF8EA), shade: SceneColor(0xDCD9C8), halo: SceneColor(0xC9D8FF))
            + [
                SceneElement(snow, SceneColor(0xFFFFFF, opacity: 0.75), still: true),
                // Snowy mountains far away, then a nearer ridge, each paler at the top where the snow catches the moon.
                SceneElement(SceneArt.ridge(seed: 103, baseline: 570, height: 120, roughness: 0.58, bottom: 610), gradient: [SceneColor(0xE4EAF8), SceneColor(0x93A1C9), SceneColor(0x5F6E9C)]),
                SceneElement(ScenePath.rect(0, 540, 390, 60), gradient: [SceneColor(0xA9B8DD, opacity: 0), SceneColor(0xA9B8DD, opacity: 0.45)], blur: 5),
                SceneElement(SceneArt.ridge(seed: 104, baseline: 598, height: 70, roughness: 0.5, bottom: 625), gradient: [SceneColor(0xA7B5D9), SceneColor(0x4F5E8C)]),
                SceneElement(SceneArt.pines(seed: 105, x: -10...400, base: 612, height: 26...48, spacing: 15), gradient: [SceneColor(0x3C4C7A), SceneColor(0x26335A)]),
                SceneElement(SceneArt.hills([(-20, 628), (90, 610), (210, 622), (320, 604), (410, 618)]), gradient: [snowLight, snowShade]),
                SceneElement(SceneArt.hills([(-20, 662), (120, 650), (260, 660), (410, 646)]), gradient: [SceneColor(0xEEF2FB), SceneColor(0xD4DCEF)])
            ]
        var lights: [SceneLight] = []
        var smoke: [CGPath] = []
        var snowCaps: [CGPath] = [], icicles: [CGPath] = [], doors: [CGPath] = [], beams: [CGPath] = []
        for (index, house) in houses.enumerated() {
            let top = house.base - house.height
            let roof = house.width * 0.45
            let chimneyX = house.x + house.width * 0.65
            background.append(SceneElement(ScenePath.rect(chimneyX, top - roof * 0.9, 9, roof * 0.7), gradient: [SceneColor(0x6A4A52), SceneColor(0x3A2A36)]))
            snowCaps.append(ScenePath.rect(chimneyX - 1.5, top - roof * 0.9 - 3, 12, 4.5, corner: 2))
            background.append(SceneElement(ScenePath.rect(house.x, top, house.width, house.height), gradient: [SceneColor(0x51476A), SceneColor(0x332B48)]))
            // Timber beams on the walls.
            beams.append(ScenePath.rect(house.x, top + 2, house.width, 2.5))
            beams.append(ScenePath.rect(house.x, house.base - 4, house.width, 4))
            let roofLine = [(house.x - 7, top + 1), (house.x + house.width / 2, top - roof), (house.x + house.width + 7, top + 1)]
            background.append(SceneElement(ScenePath.polygon(roofLine), gradient: [SceneColor(0x6B3E4E), SceneColor(0x3E2434)]))
            // A thick layer of snow along the roof, drooping over the eaves.
            snowCaps.append(ScenePath.polygon([(house.x - 10, top + 3), (house.x + house.width / 2, top - roof - 5), (house.x + house.width + 10, top + 3),
                                               (house.x + house.width + 4, top + 6), (house.x + house.width / 2, top - roof + 4), (house.x - 4, top + 6)]))
            var drip = SceneRandom(seed: 120 + UInt64(index))
            var position = house.x - 2
            while position < house.x + house.width {
                let length = drip.next(3...8)
                icicles.append(ScenePath.polygon([(position, top + 5), (position + 1.4, top + 5 + length), (position + 2.8, top + 5)]))
                position += drip.next(5...9)
            }
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
                    // A little snow on each sill.
                    snowCaps.append(ScenePath.rect(x - 1.5, y + 12, 13, 2.2, corner: 1))
                }
            }
            if index == 2 || index == 0 {
                doors.append(ScenePath.rect(house.x + house.width / 2 - 6, house.base - 18, 12, 18, corner: 2))
            }
        }
        background.append(SceneElement(ScenePath.group(beams), SceneColor(0x2A2238)))
        background.append(SceneElement(ScenePath.group(doors), gradient: [SceneColor(0x8A5A3C), SceneColor(0x5E3A26)]))
        background.append(SceneElement(ScenePath.group(snowCaps), gradient: [snowLight, SceneColor(0xDDE5F5)]))
        background.append(SceneElement(ScenePath.group(icicles), SceneColor(0xE6EEFF, opacity: 0.85)))
        // A snowy fence and a street lamp in front of the houses.
        let posts = ScenePath.group(stride(from: CGFloat(4), through: 386, by: 18).map { ScenePath.rect($0, 676, 3, 16, corner: 1) })
        let rails = ScenePath.group([ScenePath.rect(0, 680, 390, 2), ScenePath.rect(0, 687, 390, 2)])
        background.append(SceneElement(ScenePath.group([posts, rails]), SceneColor(0x4A3A4A)))
        background.append(SceneElement(ScenePath.group(stride(from: CGFloat(3), through: 385, by: 18).map { ScenePath.rect($0, 674.5, 5, 2.6, corner: 1.3) }), snowLight))
        background.append(SceneElement(ScenePath.rect(0, 692, 390, 8), gradient: [SceneColor(0xEFF3FB), SceneColor(0xD6DEF0)]))
        var flakes = SceneRandom(seed: 111)
        let bigSnow = ScenePath.group((0..<22).map { _ in
            ScenePath.star(flakes.next(0...390), flakes.next(100...560), outer: flakes.next(2.5...4), inner: 1.1, points: 6)
        })
        let completion: [SceneElement] = [
            // Aurora curtains above the moon, so the moon stays clear.
            SceneElement(ScenePath.band(from: CGPoint(x: -20, y: 120), to: CGPoint(x: 410, y: 60), bend: 30, thickness: 46),
                         gradient: [SceneColor(0x7CFFD4, opacity: 0.05), SceneColor(0x6CFFC8, opacity: 0.32), SceneColor(0x4FD8FF, opacity: 0.05)], blur: 8),
            SceneElement(ScenePath.band(from: CGPoint(x: -20, y: 175), to: CGPoint(x: 410, y: 100), bend: -14, thickness: 28),
                         gradient: [SceneColor(0xB59CFF, opacity: 0.05), SceneColor(0xA394FF, opacity: 0.28), SceneColor(0x6CFFC8, opacity: 0.04)], blur: 7),
            SceneElement(bigSnow, SceneColor(0xFFFFFF, opacity: 0.9), still: true),
            SceneElement(ScenePath.group(smoke), SceneColor(0xFFFFFF, opacity: 0.4), blur: 1.5, still: true),
            // Snowman in the lower right corner, with a hat, a scarf and twig arms.
            SceneElement(ScenePath.group([ScenePath.line([(362, 672), (352, 664)]), ScenePath.line([(378, 672), (387, 663)])]), SceneColor(0x5E3A26), lineWidth: 1.4),
            SceneElement(ScenePath.group([ScenePath.circle(370, 686, 11), ScenePath.circle(370, 669, 7.5)]), gradient: [SceneColor(0xFFFFFF), SceneColor(0xC9D4EC)]),
            SceneElement(ScenePath.group([ScenePath.rect(362, 661, 16, 3, corner: 1), ScenePath.rect(364.5, 651, 11, 11, corner: 1),
                                          ScenePath.circle(367.5, 668, 1), ScenePath.circle(372.5, 668, 1), ScenePath.circle(370, 683, 1.2), ScenePath.circle(370, 689, 1.2)]),
                         SceneColor(0x2A2440)),
            SceneElement(ScenePath.group([ScenePath.rect(362.5, 674.5, 15, 3.5, corner: 1.5), ScenePath.rect(374, 676, 4, 8, corner: 1.5)]), SceneColor(0xE8505B)),
            SceneElement(ScenePath.polygon([(370, 670), (378, 671.5), (370, 673)]), SceneColor(0xFF9A3C))
        ]
        return JourneyScene(month: 1, title: "눈 내린 마을", sky: [SceneColor(0x08122E), SceneColor(0x1D2E5C), SceneColor(0x4B5F94), SceneColor(0x8E9DC7)],
                            background: background, lights: lights, completion: completion, ambience: ambience(for: 1))
    }()

    // MARK: 2월 · 설날 청사초롱 — blue-and-red lanterns; when full, the moon, a kite and lit hanok windows

    static let newYearLanterns: JourneyScene = {
        let roofOne = SceneArt.hanokRoof(95, 602, width: 196, height: 38)
        let roofTwo = SceneArt.hanokRoof(295, 594, width: 214, height: 42)
        // Wooden posts and the stone base of each house; the doors are paper screens.
        let posts = ScenePath.group([CGFloat(22), 76, 110, 164, 214, 277, 312, 372].map { ScenePath.rect($0, 598, 5, 90) })
        let screens = ScenePath.group([ScenePath.rect(84, 650, 22, 36, corner: 1), ScenePath.rect(286, 646, 24, 40, corner: 1)])
        let screenFrames: [CGRect] = [CGRect(x: 84, y: 650, width: 22, height: 36), CGRect(x: 286, y: 646, width: 24, height: 40)]
        let screenLattice = ScenePath.group(screenFrames.flatMap { frame -> [CGPath] in
            let bars: [CGPath] = stride(from: frame.minY + 9, to: frame.maxY, by: 9).map { ScenePath.line([(frame.minX, $0), (frame.maxX, $0)]) }
            return [ScenePath.line([(frame.midX, frame.minY), (frame.midX, frame.maxY)])] + bars
        })
        // A low stone wall with a tiled cap runs along the front.
        var stones = SceneRandom(seed: 203)
        let wallStones = ScenePath.group((0..<26).map { index in
            ScenePath.rect(CGFloat(index % 13) * 30 + (index < 13 ? 0 : 15) + stones.next(-2...2), index < 13 ? 683 : 691, 27, 7, corner: 3)
        })
        var background: [SceneElement] = SceneArt.stars(seed: 201, count: 70, area: CGRect(x: 0, y: 70, width: 390, height: 220)) + [
            SceneElement(SceneArt.ridge(seed: 202, baseline: 590, height: 110, roughness: 0.55, bottom: 640), gradient: [SceneColor(0x6B4C86), SceneColor(0x3D2A5A)]),
            SceneElement(ScenePath.rect(0, 540, 390, 70), gradient: [SceneColor(0xE7A0B0, opacity: 0), SceneColor(0xE7A0B0, opacity: 0.28)], blur: 6),
            SceneElement(SceneArt.ridge(seed: 204, baseline: 620, height: 50, roughness: 0.5, bottom: 700), gradient: [SceneColor(0x45305F), SceneColor(0x2A1D40)]),
            SceneElement(ScenePath.group([ScenePath.rect(20, 600, 150, 100), ScenePath.rect(212, 592, 166, 108)]), gradient: [SceneColor(0x6A5677), SceneColor(0x45374F)]),
            SceneElement(posts, gradient: [SceneColor(0x4A2E2A), SceneColor(0x2E1C1A)]),
            SceneElement(screens, gradient: [SceneColor(0xC2AE92), SceneColor(0x96826E)]),
            SceneElement(screenLattice, SceneColor(0x4A2E2A), lineWidth: 0.8),
            SceneElement(ScenePath.group([roofOne.roof, roofTwo.roof]), gradient: [SceneColor(0x3A3550), SceneColor(0x1C1830)]),
            SceneElement(ScenePath.group([roofOne.tiles, roofTwo.tiles]), SceneColor(0x5A5476, opacity: 0.8), lineWidth: 1.4),
            SceneElement(ScenePath.group([roofOne.ridge, roofTwo.ridge]), SceneColor(0x5E587C), lineWidth: 4),
            SceneElement(ScenePath.rect(0, 676, 390, 24), gradient: [SceneColor(0x3E3046), SceneColor(0x2A2030)]),
            SceneElement(wallStones, gradient: [SceneColor(0x6E6070), SceneColor(0x4C4052)]),
            SceneElement(ScenePath.rect(-4, 672, 398, 6, corner: 2), SceneColor(0x2A2440))
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
        ] + SceneArt.moon(300, 160, radius: 28, light: SceneColor(0xFFF6D6), shade: SceneColor(0xF0D9A0)) + [
            SceneElement(ScenePath.curve(from: CGPoint(x: 95, y: 190), to: CGPoint(x: 150, y: 560), control: CGPoint(x: 60, y: 420)), SceneColor(0xF7F1E3, opacity: 0.5), lineWidth: 0.8),
            SceneElement(ScenePath.rect(80, 150, 30, 40, corner: 2), SceneColor(0xF7F1E3)),
            SceneElement(ScenePath.rect(80, 150, 30, 7), SceneColor(0xE8505B)),
            SceneElement(ScenePath.circle(95, 172, 6), SceneColor(0x3A2A63)),
            SceneElement(ScenePath.group([ScenePath.line([(80, 150), (110, 190)]), ScenePath.line([(110, 150), (80, 190)])]), SceneColor(0x4F7DF5, opacity: 0.6), lineWidth: 1),
            SceneElement(ScenePath.group(windows.map { ScenePath.rect($0.0, $0.1, $0.2, $0.3) }), SceneColor(0xFFCF7A), glow: 10),
            SceneElement(lattice, SceneColor(0x9C6A2A), lineWidth: 1.2)
        ]
        return JourneyScene(month: 2, title: "설날 청사초롱", sky: [SceneColor(0x150F36), SceneColor(0x3E2766), SceneColor(0x8E4F86), SceneColor(0xE08A8E)],
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
            SceneElement(ScenePath.arc(195, 600, radius: 250 - CGFloat(index) * 8, from: .pi, to: 2 * .pi), SceneColor(hex, opacity: 0.45), lineWidth: 8, blur: 1.5)
        }
        func butterfly(_ x: CGFloat, _ y: CGFloat, _ hex: UInt32) -> [SceneElement] {
            [SceneElement(ScenePath.group([ScenePath.ellipse(center: CGPoint(x: x - 5, y: y - 3), width: 10, height: 8, angle: -0.5),
                                           ScenePath.ellipse(center: CGPoint(x: x + 5, y: y - 3), width: 10, height: 8, angle: 0.5),
                                           ScenePath.ellipse(center: CGPoint(x: x - 4, y: y + 4), width: 6, height: 5, angle: 0.4),
                                           ScenePath.ellipse(center: CGPoint(x: x + 4, y: y + 4), width: 6, height: 5, angle: -0.4)]), SceneColor(hex), still: true),
             SceneElement(ScenePath.line([(x, y - 6), (x, y + 7)]), SceneColor(0x3B2A20), lineWidth: 1.4, still: true)]
        }
        var meadow = SceneRandom(seed: 305)
        let farTrees = ScenePath.group((0..<9).map { index in
            SceneArt.crown(seed: 310 + UInt64(index), 20 + CGFloat(index) * 44 + meadow.next(-8...8), 524 + meadow.next(-6...6), radius: meadow.next(9...14), puffs: 5)
        })
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 150, y: 700))
        path.addQuadCurve(to: CGPoint(x: 236, y: 600), control: CGPoint(x: 120, y: 640))
        path.addQuadCurve(to: CGPoint(x: 262, y: 548), control: CGPoint(x: 290, y: 572))
        path.addLine(to: CGPoint(x: 268, y: 548))
        path.addQuadCurve(to: CGPoint(x: 252, y: 602), control: CGPoint(x: 300, y: 576))
        path.addQuadCurve(to: CGPoint(x: 206, y: 700), control: CGPoint(x: 168, y: 640))
        path.closeSubpath()
        // A small cottage with a red roof on the far hill.
        let cottage = ScenePath.rect(262, 528, 30, 20)
        let cottageRoof = ScenePath.polygon([(258, 530), (277, 514), (296, 530)])
        return JourneyScene(
            month: 3, title: "봄 들판", sky: [SceneColor(0x3F7FBF), SceneColor(0x7DB6DE), SceneColor(0xBFE0EC), SceneColor(0xEAF4DC)],
            background: [
                SceneElement(ScenePath.circle(80, 250, 70), SceneColor(0xFFF8D6, opacity: 0.25), blur: 22),
                SceneElement(ScenePath.circle(80, 250, 24), gradient: [SceneColor(0xFFFDEB), SceneColor(0xFFF0B8)], glow: 14),
                SceneElement(ScenePath.group([SceneArt.cloud(190, 210, width: 130), SceneArt.cloud(10, 360, width: 90), SceneArt.cloud(286, 330, width: 100)]),
                             gradient: [SceneColor(0xFFFFFF, opacity: 0.95), SceneColor(0xDCEBF5, opacity: 0.9)]),
                SceneElement(SceneArt.ridge(seed: 306, baseline: 540, height: 80, roughness: 0.5, bottom: 560), gradient: [SceneColor(0x9EBBD9), SceneColor(0xA9C9D8)]),
                SceneElement(SceneArt.hills([(-30, 540), (80, 512), (200, 530), (300, 506), (420, 528)], bottom: 600), gradient: [SceneColor(0xB5DB8E), SceneColor(0x93C772)]),
                SceneElement(farTrees, gradient: [SceneColor(0x7DB862), SceneColor(0x5A9A4A)]),
                SceneElement(cottage, gradient: [SceneColor(0xFFF6E6), SceneColor(0xE6D8C0)]),
                SceneElement(cottageRoof, SceneColor(0xD9534F)),
                SceneElement(ScenePath.group([ScenePath.rect(268, 534, 6, 6), ScenePath.rect(281, 536, 6, 12)]), SceneColor(0x8A6A4A)),
                SceneElement(SceneArt.hills([(-30, 576), (100, 552), (240, 570), (420, 548)]), gradient: [SceneColor(0x9CCF72), SceneColor(0x6FAE52)]),
                SceneElement(path, gradient: [SceneColor(0xEBDDB8), SceneColor(0xD8C394)]),
                SceneElement(SceneArt.grass(seed: 307, count: 90, x: 0...390, baseline: 600, height: 6...12, width: 2), SceneColor(0x5E9E48, opacity: 0.8)),
                SceneElement(stems, SceneColor(0x3F7D3A), lineWidth: 1.5),
                SceneElement(leaves, SceneColor(0x4E9447))
            ],
            lights: lights,
            foreground: [SceneElement(SceneArt.grass(seed: 308, count: 120, x: -5...395, baseline: 700, height: 6...14, width: 3), gradient: [SceneColor(0x6DB056), SceneColor(0x3F7D3A)])],
            completion: rainbow
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
        // Soft pink masses behind the blossoms give the canopy its body.
        let canopy = ScenePath.group([(CGFloat(195), CGFloat(400), CGFloat(120)), (105, 450, 78), (290, 452, 80), (150, 350, 72), (245, 345, 74), (195, 480, 70)].enumerated().map { index, spot in
            SceneArt.crown(seed: 420 + UInt64(index), spot.0, spot.1, radius: spot.2, puffs: 8)
        })
        // Lighter puffs on the upper left, where the light falls on the canopy.
        let canopyLight = ScenePath.group([(CGFloat(165), CGFloat(370), CGFloat(70)), (110, 430, 44), (220, 330, 46)].enumerated().map { index, spot in
            SceneArt.crown(seed: 440 + UInt64(index), spot.0, spot.1, radius: spot.2, puffs: 6)
        })
        let reflection = SceneArt.shimmer(seed: 430, x: 76, top: 640, bottom: 690, width: 60, rows: 7)
        // A stone lantern beside the tree.
        let stoneLantern = ScenePath.group([ScenePath.rect(326, 628, 8, 30), ScenePath.rect(318, 610, 24, 18, corner: 2),
                                            ScenePath.polygon([(312, 612), (330, 596), (348, 612)]), ScenePath.rect(316, 656, 28, 6, corner: 2)])
        return JourneyScene(
            month: 4, title: "벚꽃나무", sky: [SceneColor(0x2A1E4E), SceneColor(0x6E3E7E), SceneColor(0xC46C94), SceneColor(0xF6BCC6)],
            background: SceneArt.stars(seed: 401, count: 50, area: CGRect(x: 0, y: 60, width: 390, height: 200)) + [
                SceneElement(SceneArt.ridge(seed: 402, baseline: 640, height: 70, roughness: 0.5, bottom: 660), gradient: [SceneColor(0x9A5E8E), SceneColor(0x7A4A78)]),
                SceneElement(ScenePath.rect(0, 600, 390, 60), gradient: [SceneColor(0xF6BCC6, opacity: 0), SceneColor(0xF6BCC6, opacity: 0.35)], blur: 6),
                // A pond on the left catches the evening light.
                SceneElement(ScenePath.ellipse(-40, 632, 250, 62), gradient: [SceneColor(0xE7A6C0), SceneColor(0x8E5C8E)]),
                SceneElement(reflection, SceneColor(0xFFE1EA, opacity: 0.55)),
                SceneElement(SceneArt.hills([(-30, 676), (120, 664), (230, 648), (420, 660)]), gradient: [SceneColor(0x6E4466), SceneColor(0x4A2C48)]),
                SceneElement(canopy, gradient: [SceneColor(0xF7B3C8, opacity: 0.55), SceneColor(0xD87FA4, opacity: 0.55)]),
                SceneElement(canopyLight, SceneColor(0xFFE1EA, opacity: 0.22)),
                SceneElement(SceneArt.trunk(root: CGPoint(x: 195, y: 690), fork: CGPoint(x: 192, y: 540), width: 22, branches: [
                    (CGPoint(x: 80, y: 440), 3), (CGPoint(x: 125, y: 370), 3), (CGPoint(x: 198, y: 320), 3), (CGPoint(x: 265, y: 360), 3),
                    (CGPoint(x: 315, y: 438), 3), (CGPoint(x: 150, y: 470), 2.5), (CGPoint(x: 245, y: 468), 2.5)
                ]), gradient: [SceneColor(0x5A3446), SceneColor(0x3A2030)]),
                SceneElement(stoneLantern, gradient: [SceneColor(0x8A7A8E), SceneColor(0x5A4A62)]),
                SceneElement(SceneArt.grass(seed: 403, count: 80, x: 0...390, baseline: 700, height: 5...12, width: 2.4), SceneColor(0x3E2440)),
                SceneElement(petals, SceneColor(0xFFC4D6, opacity: 0.7), still: true)
            ],
            lights: lights,
            completion: SceneArt.moon(76, 190, radius: 22, light: SceneColor(0xFFF4F6), shade: SceneColor(0xF2D2DC), halo: SceneColor(0xFFD6E2), seas: false) + [
                SceneElement(ScenePath.rect(325, 613, 10, 12, corner: 1), SceneColor(0xFFD27A), glow: 8),
                SceneElement(ScenePath.ellipse(-40, 664, 470, 40), SceneColor(0xFFC4D6, opacity: 0.5), blur: 3),
                SceneElement(carpet, SceneColor(0xFFD9E4)),
                SceneElement(fallingPetals, SceneColor(0xFFD1DF, opacity: 0.95), still: true)
            ],
            ambience: ambience(for: 4)
        )
    }()

    // MARK: 5월 · 연등 — lotus lanterns over a temple; when full, the temple glows under the moon

    static let lotusLanterns: JourneyScene = {
        let colors = [SceneColor(0xFF8FB1), SceneColor(0xFFD66B), SceneColor(0x8EE3A1), SceneColor(0xFFA86B), SceneColor(0xC69CFF)]
        let lowerRoof = SceneArt.hanokRoof(195, 608, width: 330, height: 48)
        let upperRoof = SceneArt.hanokRoof(195, 534, width: 176, height: 32)
        // Red pillars and a painted green band under the eaves, as on a temple hall.
        let pillars = ScenePath.group([CGFloat(64), 140, 244, 320].map { ScenePath.rect($0, 606, 6, 94) } + [ScenePath.rect(134, 532, 5, 34), ScenePath.rect(251, 532, 5, 34)])
        let steps = ScenePath.group([ScenePath.rect(150, 688, 90, 6), ScenePath.rect(140, 694, 110, 6)])
        // A stone pagoda to the right of the hall.
        let pagodaRoofs: [CGPath] = (0..<4).map { tier -> CGPath in
            let inset = CGFloat(tier) * 2, y = 640 - CGFloat(tier) * 18
            return ScenePath.polygon([(340 + inset, y), (390 - inset, y), (384 - inset, y - 6), (346 + inset, y - 6)])
        }
        let pagoda = ScenePath.group([ScenePath.rect(352, 620, 26, 80), ScenePath.rect(362, 556, 6, 12)] + pagodaRoofs)
        var background: [SceneElement] = SceneArt.stars(seed: 501, count: 60, area: CGRect(x: 0, y: 60, width: 390, height: 170)) + [
            SceneElement(SceneArt.ridge(seed: 502, baseline: 600, height: 130, roughness: 0.55, bottom: 650), gradient: [SceneColor(0x2E3470), SceneColor(0x1A1D48)]),
            SceneElement(ScenePath.rect(0, 560, 390, 70), gradient: [SceneColor(0x6A6FB0, opacity: 0), SceneColor(0x6A6FB0, opacity: 0.3)], blur: 6),
            SceneElement(SceneArt.pines(seed: 503, x: -10...60, base: 640, height: 50...80, spacing: 22), SceneColor(0x111433)),
            SceneElement(SceneArt.pines(seed: 504, x: 336...400, base: 630, height: 50...80, spacing: 24), SceneColor(0x111433)),
            SceneElement(ScenePath.rect(130, 530, 130, 36), gradient: [SceneColor(0x2C2F5E), SceneColor(0x1C1F44)]),
            SceneElement(ScenePath.rect(60, 604, 270, 96), gradient: [SceneColor(0x2C2F5E), SceneColor(0x1A1C40)]),
            SceneElement(pillars, gradient: [SceneColor(0x8A2E36), SceneColor(0x5E1E26)]),
            SceneElement(ScenePath.group([ScenePath.rect(60, 604, 270, 7), ScenePath.rect(130, 530, 130, 5)]), SceneColor(0x2F7A66)),
            SceneElement(ScenePath.group([upperRoof.roof, lowerRoof.roof]), gradient: [SceneColor(0x262A52), SceneColor(0x10122C)]),
            SceneElement(ScenePath.group([upperRoof.tiles, lowerRoof.tiles]), SceneColor(0x3E4378, opacity: 0.8), lineWidth: 1.4),
            SceneElement(ScenePath.group([upperRoof.ridge, lowerRoof.ridge]), SceneColor(0x4A508A), lineWidth: 4),
            SceneElement(ScenePath.rect(170, 640, 50, 48, corner: 3), gradient: [SceneColor(0x3A3F72), SceneColor(0x2A2F5A)]),
            SceneElement(steps, gradient: [SceneColor(0x5A5E8E), SceneColor(0x3A3E6A)]),
            SceneElement(pagoda, gradient: [SceneColor(0x6A6E9A), SceneColor(0x3E4270)])
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
            month: 5, title: "연등", sky: [SceneColor(0x090D2B), SceneColor(0x1A2356), SceneColor(0x37397A), SceneColor(0x5E4A8A)],
            background: background, lights: lights,
            completion: SceneArt.moon(322, 150, radius: 22) + [
                SceneElement(sparkles, SceneColor(0xFFFFFF, opacity: 0.85), glow: 4, still: true),
                SceneElement(ScenePath.group([ScenePath.rect(92, 628, 40, 26, corner: 2), ScenePath.rect(258, 628, 40, 26, corner: 2), ScenePath.rect(150, 538, 90, 18, corner: 2)]),
                             SceneColor(0xFFCF7A), glow: 10),
                SceneElement(ScenePath.rect(170, 640, 50, 48, corner: 3), SceneColor(0xFFB65C), glow: 14),
                SceneElement(ScenePath.group([ScenePath.line([(195, 640), (195, 688)])] + stride(from: CGFloat(652), to: 688, by: 12).map { ScenePath.line([(170, $0), (220, $0)]) }),
                             SceneColor(0xB0702A, opacity: 0.8), lineWidth: 1)
            ],
            ambience: ambience(for: 5)
        )
    }()

    // MARK: 6월 · 반딧불이 숲 — fireflies gather; when full, a moonlit pond and a swarm of fireflies

    static let fireflyForest: JourneyScene = {
        var background: [SceneElement] = SceneArt.stars(seed: 601, count: 50, area: CGRect(x: 0, y: 60, width: 390, height: 260), color: SceneColor(0xE6F5E0))
            + SceneArt.moon(310, 200, radius: 18, light: SceneColor(0xF6F3D8), shade: SceneColor(0xDCD8B4), halo: SceneColor(0xCFF0D0), seas: false)
        // Three layers of forest, paler and hazier with distance.
        background += [
            SceneElement(SceneArt.ridge(seed: 602, baseline: 520, height: 70, roughness: 0.5, bottom: 560), gradient: [SceneColor(0x1F4E40), SceneColor(0x173D33)]),
            SceneElement(SceneArt.pines(seed: 603, x: -10...400, base: 540, height: 40...70, spacing: 16), gradient: [SceneColor(0x1A4A3A), SceneColor(0x143A2E)]),
            SceneElement(ScenePath.rect(0, 500, 390, 70), gradient: [SceneColor(0x9FD6B8, opacity: 0), SceneColor(0x9FD6B8, opacity: 0.18), SceneColor(0x9FD6B8, opacity: 0)], blur: 8),
            SceneElement(SceneArt.pines(seed: 604, x: -20...410, base: 610, height: 90...150, spacing: 30), gradient: [SceneColor(0x0F3428), SceneColor(0x0B2A20)]),
            SceneElement(ScenePath.rect(0, 590, 390, 50), gradient: [SceneColor(0x7FC4A0, opacity: 0), SceneColor(0x7FC4A0, opacity: 0.14), SceneColor(0x7FC4A0, opacity: 0)], blur: 8),
            SceneElement(SceneArt.hills([(-30, 648), (130, 636), (260, 646), (420, 632)]), gradient: [SceneColor(0x0C2A20), SceneColor(0x061A14)]),
            // A pond holding the moon.
            SceneElement(ScenePath.ellipse(20, 650, 190, 32), gradient: [SceneColor(0x1E5060), SceneColor(0x0D2A36)]),
            SceneElement(SceneArt.shimmer(seed: 605, x: 115, top: 656, bottom: 676, width: 40, rows: 5), SceneColor(0xF6F3D8, opacity: 0.4)),
            SceneElement(SceneArt.pines(seed: 606, x: 300...420, base: 700, height: 150...210, spacing: 46), SceneColor(0x04140F)),
            SceneElement(SceneArt.pines(seed: 607, x: -30...40, base: 700, height: 170...220, spacing: 50), SceneColor(0x04140F))
        ]
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
            foreground: [SceneElement(grass, SceneColor(0x041510)),
                         SceneElement(SceneArt.grass(seed: 608, count: 40, x: 10...210, baseline: 686, height: 14...30, width: 2), SceneColor(0x062018))],
            completion: [
                SceneElement(ScenePath.circle(310, 200, 60), SceneColor(0xE9FF8C, opacity: 0.08), blur: 20),
                SceneElement(ScenePath.ellipse(20, 640, 190, 50), SceneColor(0xE9FF8C, opacity: 0.08), blur: 12),
                SceneElement(smallFlies, SceneColor(0xE9FF8C, opacity: 0.75), glow: 5, still: true)
            ],
            ambience: ambience(for: 6)
        )
    }()

    // MARK: 7월 · 여름 바다 — stars come out; when full, the Milky Way, a shooting star and a sailboat

    static let summerSea: JourneyScene = {
        let lighthouse = ScenePath.polygon([(318, 568), (322, 470), (338, 470), (342, 568)])
        let stripes = ScenePath.group([ScenePath.polygon([(320.8, 500), (339.2, 500), (339.6, 512), (320.4, 512)]),
                                       ScenePath.polygon([(319.6, 532), (340.4, 532), (340.9, 545), (319.1, 545)])])
        let background: [SceneElement] = SceneArt.stars(seed: 701, count: 120, area: CGRect(x: 0, y: 60, width: 390, height: 480)) + SceneArt.moon(80, 230, radius: 24) + [
            // The horizon glows faintly where the sky meets the sea.
            SceneElement(ScenePath.rect(0, 500, 390, 70), gradient: [SceneColor(0x3A6AA8, opacity: 0), SceneColor(0x5A86C0, opacity: 0.45)], blur: 6),
            SceneElement(SceneArt.ridge(seed: 702, baseline: 562, height: 22, roughness: 0.5, left: 120, right: 260, bottom: 562), SceneColor(0x15305A)),
            SceneElement(ScenePath.rect(0, 560, 390, 140), gradient: [SceneColor(0x1A3E6E), SceneColor(0x0C2448), SceneColor(0x061632)]),
            SceneElement(SceneArt.ripples(seed: 703, area: CGRect(x: 0, y: 566, width: 390, height: 130), count: 60), SceneColor(0x6A92C8, opacity: 0.35), lineWidth: 0.8),
            SceneElement(SceneArt.shimmer(seed: 704, x: 80, top: 566, bottom: 690, width: 56, rows: 12), SceneColor(0xF8F4DC, opacity: 0.45)),
            SceneElement(ScenePath.polygon([(330, 463), (190, 425), (190, 480)]), gradient: [SceneColor(0xFFF2A8, opacity: 0.16), SceneColor(0xFFF2A8, opacity: 0.04)], blur: 3),
            // Rocks under the lighthouse.
            SceneElement(ScenePath.polygon([(250, 700), (262, 610), (286, 584), (312, 568), (360, 562), (390, 574), (390, 700)]), gradient: [SceneColor(0x1C2E4E), SceneColor(0x081428)]),
            SceneElement(ScenePath.polygon([(262, 612), (286, 586), (300, 600), (284, 640)]), SceneColor(0x2A3E62, opacity: 0.7)),
            SceneElement(ScenePath.group([ScenePath.ellipse(240, 676, 40, 14), ScenePath.ellipse(222, 690, 30, 10)]), SceneColor(0x0A1A33)),
            SceneElement(SceneArt.ripples(seed: 705, area: CGRect(x: 214, y: 670, width: 70, height: 26), count: 6), SceneColor(0xDCE8FF, opacity: 0.5), lineWidth: 1),
            SceneElement(lighthouse, gradient: [SceneColor(0xF4F2FA), SceneColor(0xB8BCD4)]),
            SceneElement(stripes, SceneColor(0xD9534F)),
            SceneElement(ScenePath.rect(312, 466, 36, 4, corner: 1), SceneColor(0x2A2F4A)),
            SceneElement(ScenePath.group([CGFloat(316), 323, 330, 337, 344].map { ScenePath.line([($0, 455), ($0, 466)]) }), SceneColor(0x2A2F4A), lineWidth: 1),
            SceneElement(ScenePath.rect(318, 455, 24, 11), SceneColor(0x3A405E)),
            SceneElement(ScenePath.polygon([(314, 456), (330, 440), (346, 456)]), gradient: [SceneColor(0xE86A64), SceneColor(0xB8433E)]),
            SceneElement(ScenePath.circle(330, 461, 5), SceneColor(0xFFF2A8), glow: 8),
            SceneElement(ScenePath.rect(326, 552, 8, 16, corner: 1), SceneColor(0x4A3A3A))
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
            month: 7, title: "여름 바다", sky: [SceneColor(0x020617), SceneColor(0x0A1C46), SceneColor(0x1B3F74), SceneColor(0x33609A)],
            background: background, lights: lights,
            completion: [
                SceneElement(ScenePath.band(from: CGPoint(x: -20, y: 300), to: CGPoint(x: 410, y: 95), bend: -30, thickness: 62),
                             gradient: [SceneColor(0xB9A8FF, opacity: 0.08), SceneColor(0xDDE6FF, opacity: 0.22), SceneColor(0xFFD9C2, opacity: 0.08)], blur: 14),
                SceneElement(milkyDots, SceneColor(0xFFFFFF, opacity: 0.6)),
                SceneElement(ScenePath.polygon([(160, 176), (58, 120), (55, 126)]), SceneColor(0xFFFFFF, opacity: 0.85), glow: 6, still: true),
                SceneElement(ScenePath.circle(160, 176, 2.4), SceneColor(0xFFFFFF), glow: 6, still: true),
                SceneElement(ScenePath.polygon([(330, 463), (160, 405), (160, 510)]), gradient: [SceneColor(0xFFF2A8, opacity: 0.24), SceneColor(0xFFF2A8, opacity: 0.06)], blur: 4),
                SceneElement(ScenePath.line([(166, 532), (166, 588)]), SceneColor(0x3A3040), lineWidth: 1.4),
                SceneElement(ScenePath.polygon([(165, 538), (165, 584), (138, 584)]), gradient: [SceneColor(0xFFFFFF), SceneColor(0xC9CCE0)]),
                SceneElement(ScenePath.polygon([(169, 548), (169, 584), (188, 584)]), SceneColor(0xE8E6F0, opacity: 0.8)),
                SceneElement(ScenePath.polygon([(134, 587), (194, 587), (184, 598), (144, 598)]), gradient: [SceneColor(0x6A3A2A), SceneColor(0x3A1E16)]),
                SceneElement(SceneArt.shimmer(seed: 706, x: 164, top: 602, bottom: 624, width: 50, rows: 4), SceneColor(0xE8E6F0, opacity: 0.25)),
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
        // Rooftop details: antennas and water tanks.
        let rooftops = ScenePath.group([ScenePath.rect(83, 490, 2, 12), ScenePath.rect(178, 555, 14, 10, corner: 2), ScenePath.rect(273, 512, 2, 14),
                                        ScenePath.rect(330, 528, 12, 12, corner: 2), ScenePath.rect(18, 562, 10, 8, corner: 2)])
        // A bridge with lit lamps across the river, and a far skyline in the haze.
        let bridgeDeck = ScenePath.rect(-10, 648, 410, 5)
        let bridgeArches = ScenePath.group(stride(from: CGFloat(-10), to: 400, by: 70).map { ScenePath.arc($0 + 35, 680, radius: 34, from: .pi, to: 2 * .pi) })
        let bridgeLamps = ScenePath.group(stride(from: CGFloat(8), to: 390, by: 26).map { ScenePath.circle($0, 645, 1.6) })
        let farSkyline = ScenePath.group((0..<18).map { index -> CGPath in
            var random = SceneRandom(seed: 830 + UInt64(index))
            return ScenePath.rect(CGFloat(index) * 22 - 4, 640 - random.next(70...170), 20, 200)
        })
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
            month: 8, title: "불꽃놀이", sky: [SceneColor(0x05051A), SceneColor(0x150F3C), SceneColor(0x2E1D58), SceneColor(0x5A2E6A)],
            background: SceneArt.stars(seed: 801, count: 40, area: CGRect(x: 0, y: 60, width: 390, height: 120)) + [
                SceneElement(farSkyline, gradient: [SceneColor(0x3A2A66), SceneColor(0x2A1E50)]),
                SceneElement(ScenePath.rect(0, 470, 390, 120), gradient: [SceneColor(0x8A5AA0, opacity: 0), SceneColor(0x8A5AA0, opacity: 0.3)], blur: 10),
                SceneElement(ScenePath.group(skyline), gradient: [SceneColor(0x1A1638), SceneColor(0x0B0A1F)]),
                SceneElement(rooftops, SceneColor(0x0B0A1F)),
                SceneElement(ScenePath.rect(0, 640, 390, 60), gradient: [SceneColor(0x241C52), SceneColor(0x0A0A24)]),
                SceneElement(SceneArt.ripples(seed: 802, area: CGRect(x: 0, y: 656, width: 390, height: 44), count: 40), SceneColor(0x6A5AA8, opacity: 0.4), lineWidth: 0.8),
                SceneElement(bridgeArches, SceneColor(0x1A1638), lineWidth: 4),
                SceneElement(bridgeDeck, SceneColor(0x1A1638)),
                SceneElement(bridgeLamps, SceneColor(0xFFD27A), glow: 4)
            ],
            lights: lights,
            completion: [
                SceneElement(finale.rays, SceneColor(0xFFE08A), lineWidth: 2.2, glow: 12, still: true),
                SceneElement(finale.tips, SceneColor(0xFFF6D5), glow: 6, still: true),
                SceneElement(finaleInner.rays, SceneColor(0xFF9FD0), lineWidth: 1.8, glow: 8, still: true),
                SceneElement(ScenePath.group(cityWindows), SceneColor(0xFFD27A, opacity: 0.9)),
                SceneElement(reflections, SceneColor(0xFFC46B, opacity: 0.35), blur: 1),
                SceneElement(ScenePath.rect(0, 380, 390, 220), gradient: [SceneColor(0xFFB0D0, opacity: 0), SceneColor(0xFFB0D0, opacity: 0.08)], blur: 12)
            ],
            ambience: ambience(for: 8)
        )
    }()

    // MARK: 9월 · 한가위 풍등 — sky lanterns rise; when full, the moon rabbit and a lit village

    static let harvestMoon: JourneyScene = {
        let houseSpots: [(CGFloat, CGFloat)] = [(14, 72), (116, 80), (224, 68), (306, 76)]
        let hanokRoofs = houseSpots.map { x, width in SceneArt.hanokRoof(x + width / 2, 648, width: width + 26, height: 28) }
        // Silver grass along the bottom, its plumes catching the moonlight.
        var plumeRandom = SceneRandom(seed: 931)
        var stalks: [CGPath] = [], plumeShapes: [CGPath] = []
        for _ in 0..<14 {
            let x = plumeRandom.next(0...390), top = plumeRandom.next(612...650), lean = plumeRandom.next(-14...14)
            stalks.append(ScenePath.curve(from: CGPoint(x: x, y: 700), to: CGPoint(x: x + lean, y: top), control: CGPoint(x: x, y: top + 30)))
            plumeShapes.append(ScenePath.petal(from: CGPoint(x: x + lean, y: top + 4), length: 26, width: 6, angle: -.pi / 2 + lean / 40))
        }
        let plumes = ScenePath.group(plumeShapes)
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
            month: 9, title: "한가위 풍등", sky: [SceneColor(0x0B1233), SceneColor(0x232760), SceneColor(0x5A4282), SceneColor(0xA9688A)],
            background: SceneArt.stars(seed: 901, count: 60, area: CGRect(x: 0, y: 60, width: 390, height: 260), avoiding: { hypot($0.x - 290, $0.y - 200) < 80 })
                + SceneArt.moon(290, 200, radius: 48, light: SceneColor(0xFFF6D2), shade: SceneColor(0xF2D58E), halo: SceneColor(0xFFE6A8), seas: false) + [
                // Thin clouds drift across the lower edge of the moon.
                SceneElement(ScenePath.group([ScenePath.ellipse(206, 228, 130, 10), ScenePath.ellipse(250, 240, 120, 8)]), SceneColor(0x6A5A92, opacity: 0.55), blur: 3),
                SceneElement(SceneArt.ridge(seed: 902, baseline: 600, height: 90, roughness: 0.5, bottom: 640), gradient: [SceneColor(0x3E3470), SceneColor(0x2A2452)]),
                SceneElement(ScenePath.rect(0, 560, 390, 70), gradient: [SceneColor(0xC48AA0, opacity: 0), SceneColor(0xC48AA0, opacity: 0.25)], blur: 6),
                SceneElement(SceneArt.hills([(-30, 630), (100, 608), (240, 624), (420, 606)]), gradient: [SceneColor(0x2A2450), SceneColor(0x1A1636)]),
                SceneElement(houses, gradient: [SceneColor(0x3A3058), SceneColor(0x241E3C)]),
                SceneElement(ScenePath.group(hanokRoofs.map(\.roof)), gradient: [SceneColor(0x2C2A4E), SceneColor(0x15132C)]),
                SceneElement(ScenePath.group(hanokRoofs.map(\.tiles)), SceneColor(0x4A4676, opacity: 0.8), lineWidth: 1.2),
                SceneElement(ScenePath.group(hanokRoofs.map(\.ridge)), SceneColor(0x55508A), lineWidth: 3.5),
                SceneElement(SceneArt.grass(seed: 932, count: 40, x: 0...390, baseline: 700, height: 12...26, width: 2.6), SceneColor(0x1E1A32)),
                SceneElement(ScenePath.group(stalks), SceneColor(0x3A3252), lineWidth: 1.2),
                SceneElement(plumes, gradient: [SceneColor(0xF4E6CC), SceneColor(0xB8A4A8, opacity: 0.8)], glow: 2)
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
        let canopy = ScenePath.group([(CGFloat(195), CGFloat(410), CGFloat(122)), (100, 455, 76), (292, 455, 78), (150, 345, 70), (245, 342, 72), (195, 490, 66)].enumerated().map { index, spot in
            SceneArt.crown(seed: 1020 + UInt64(index), spot.0, spot.1, radius: spot.2, puffs: 8)
        })
        // Lighter puffs on the upper left, where the light falls on the canopy.
        let canopyLight = ScenePath.group([(CGFloat(165), CGFloat(370), CGFloat(70)), (110, 430, 44), (220, 330, 46)].enumerated().map { index, spot in
            SceneArt.crown(seed: 1040 + UInt64(index), spot.0, spot.1, radius: spot.2, puffs: 6)
        })
        // A bench under the tree.
        let bench = ScenePath.group([ScenePath.rect(250, 652, 64, 5, corner: 1.5), ScenePath.rect(250, 640, 64, 4, corner: 1.5),
                                     ScenePath.rect(254, 657, 4, 16), ScenePath.rect(306, 657, 4, 16), ScenePath.rect(254, 644, 3, 10), ScenePath.rect(307, 644, 3, 10)])
        return JourneyScene(
            month: 10, title: "단풍", sky: [SceneColor(0x241638), SceneColor(0x6E3A52), SceneColor(0xC8664A), SceneColor(0xF4AE62)],
            background: [
                SceneElement(ScenePath.circle(300, 585, 80), SceneColor(0xFFC878, opacity: 0.35), blur: 24),
                SceneElement(ScenePath.circle(300, 590, 38), gradient: [SceneColor(0xFFF0C0), SceneColor(0xFFC070)], glow: 18),
                SceneElement(SceneArt.ridge(seed: 1002, baseline: 615, height: 90, roughness: 0.55, bottom: 650), gradient: [SceneColor(0xA85A4A), SceneColor(0x7E3E3C)]),
                SceneElement(SceneArt.ridge(seed: 1003, baseline: 640, height: 60, roughness: 0.5, bottom: 680), gradient: [SceneColor(0x8A3A2E), SceneColor(0x5E2A26)]),
                SceneElement(SceneArt.hills([(-30, 668), (110, 652), (250, 664), (420, 650)]), gradient: [SceneColor(0x5A2E24), SceneColor(0x3A1C18)]),
                SceneElement(canopy, gradient: [SceneColor(0xF2A050, opacity: 0.5), SceneColor(0xC8502E, opacity: 0.5)]),
                SceneElement(canopyLight, SceneColor(0xFFD08A, opacity: 0.2)),
                SceneElement(SceneArt.trunk(root: CGPoint(x: 195, y: 690), fork: CGPoint(x: 192, y: 540), width: 22, branches: [
                    (CGPoint(x: 80, y: 445), 3), (CGPoint(x: 128, y: 365), 3), (CGPoint(x: 196, y: 318), 3), (CGPoint(x: 262, y: 362), 3),
                    (CGPoint(x: 318, y: 442), 3), (CGPoint(x: 148, y: 478), 2.5), (CGPoint(x: 244, y: 476), 2.5)
                ]), gradient: [SceneColor(0x4A2A24), SceneColor(0x2A1614)]),
                SceneElement(bench, gradient: [SceneColor(0x6A3E2A), SceneColor(0x3E2418)]),
                SceneElement(SceneArt.grass(seed: 1004, count: 70, x: 0...390, baseline: 700, height: 5...12, width: 2.4), SceneColor(0x3A1C18)),
                SceneElement(fallen, SceneColor(0xE8452C, opacity: 0.85))
            ],
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
        // When the month is full, distant towers rise behind the existing rooftops. Each stands in open sky and ends
        // exactly on the roof line in front of it, so it reads as further back; its windows sit in a regular grid.
        let towers: [(x: CGFloat, width: CGFloat, top: CGFloat, roof: CGFloat)] = [
            (18, 36, 282, 350), (78, 36, 318, 385), (208, 44, 318, 525), (320, 40, 300, 385)
        ]
        var towerWindows: [CGPath] = []
        for tower in towers {
            let columns = Int((tower.width - 6) / 10)
            let left = tower.x + (tower.width - CGFloat(columns) * 10 + 5) / 2
            for y in stride(from: tower.top + 9, through: tower.roof - 14, by: 12) {
                for column in 0..<columns {
                    towerWindows.append(ScenePath.rect(left + CGFloat(column) * 10, y, 5, 7))
                }
            }
        }
        let towerShapes = ScenePath.group(towers.map { ScenePath.rect($0.x, $0.top, $0.width, $0.roof - $0.top) }
                                          + [ScenePath.polygon([(222, 318), (230, 296), (238, 318)])])
        // A far skyline in the evening haze, and rooftop details on the near buildings.
        var cityRandom = SceneRandom(seed: 1120)
        var farBlocks: [CGPath] = [], farLights: [CGPath] = []
        var left: CGFloat = -6
        while left < 396 {
            let width = cityRandom.next(18...34), top = cityRandom.next(330...410)
            farBlocks.append(ScenePath.rect(left, top, width, 700 - top))
            for y in stride(from: top + 6, to: 480, by: 9) where cityRandom.next() > 0.6 {
                farLights.append(ScenePath.rect(left + cityRandom.next(3...(width - 6)), y, 2.5, 3.5))
            }
            left += width + cityRandom.next(0...4)
        }
        let farCity = ScenePath.group(farBlocks), farWindows = ScenePath.group(farLights)
        let backDetails = ScenePath.group([ScenePath.rect(20, 340, 10, 10, corner: 2), ScenePath.rect(100, 375, 2, 10), ScenePath.rect(300, 378, 14, 10, corner: 2),
                                           ScenePath.rect(340, 326, 2, 14), ScenePath.rect(356, 330, 12, 8, corner: 2)])
        let frontDetails = ScenePath.group([ScenePath.rect(20, 446, 12, 10, corner: 2), ScenePath.rect(120, 448, 2, 7), ScenePath.rect(195, 518, 12, 8, corner: 2),
                                            ScenePath.rect(290, 410, 16, 10, corner: 2)])
        let frontEdges = ScenePath.group([ScenePath.line([(0, 455), (34, 455)]), ScenePath.line([(95.5, 455), (148, 455)]), ScenePath.line([(205, 525), (259, 525)]),
                                          ScenePath.line([(265, 420), (351, 420)]), ScenePath.line([(351, 455), (382, 455)])])
        var random = SceneRandom(seed: 1111)
        let stars = ScenePath.group((0..<22).map { _ in ScenePath.circle(random.next(10...380), random.next(90...270), random.next(0.8...1.6)) })
        return JourneyScene(
            month: 11, title: "도시의 밤", sky: [SceneColor(0x2A1050), SceneColor(0x6A2287), SceneColor(0xB4419A), SceneColor(0xF07A9E)],
            background: [
                SceneElement(farCity, gradient: [SceneColor(0x9A4A9E, opacity: 0.7), SceneColor(0xB4519A, opacity: 0.5)]),
                SceneElement(farWindows, SceneColor(0xFFD9A0, opacity: 0.45)),
                SceneElement(ScenePath.rect(0, 300, 390, 160), gradient: [SceneColor(0xF07A9E, opacity: 0), SceneColor(0xF07A9E, opacity: 0.25)], blur: 10),
                SceneElement(back, gradient: [SceneColor(0x5E4A72), SceneColor(0x3A2C4C)]),
                SceneElement(backDetails, SceneColor(0x3A2C4C)),
                SceneElement(front, gradient: [SceneColor(0x1C1430), SceneColor(0x06040C)]),
                SceneElement(frontDetails, SceneColor(0x06040C)),
                SceneElement(frontEdges, SceneColor(0xF07A9E, opacity: 0.35), lineWidth: 1)
            ],
            lights: lights,
            completion: SceneArt.moon(312, 150, radius: 20) + [
                SceneElement(stars, SceneColor(0xFFFFFF, opacity: 0.85), still: true),
                SceneElement(towerShapes, SceneColor(0x6E5B85)),
                SceneElement(ScenePath.line([(230, 296), (230, 284)]), SceneColor(0x6E5B85), lineWidth: 1.5),
                SceneElement(ScenePath.circle(230, 283, 2.2), SceneColor(0xFF4D4D), glow: 6),
                SceneElement(ScenePath.group(towerWindows), SceneColor(0xFFE9A0, opacity: 0.9), glow: 3),
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
        // Each tier of the tree droops into soft scallops, with snow resting along its lower edge.
        func tier(_ tip: CGFloat, _ base: CGFloat, _ half: CGFloat) -> (body: CGPath, snow: CGPath) {
            let scallops = max(Int(half / 14), 3)
            var points: [(CGFloat, CGFloat)] = [(195, tip), (195 + half, base)]
            var snowPoints: [(CGFloat, CGFloat)] = []
            for index in stride(from: scallops, through: 0, by: -1) {
                let x = 195 - half + 2 * half * CGFloat(index) / CGFloat(scallops)
                points.append((x, base + (index.isMultiple(of: 2) ? 0 : 6)))
                snowPoints.append((x, base - 4 + (index.isMultiple(of: 2) ? 0 : 6)))
            }
            let snow = ScenePath.polygon(snowPoints + points.dropFirst(2).reversed().map { ($0.0, $0.1 + 0.5) })
            return (ScenePath.polygon(points), snow)
        }
        let treeTiers = tiers.map { tier($0.tip, $0.base, $0.half) }
        var background: [SceneElement] = SceneArt.stars(seed: 1201, count: 90, area: CGRect(x: 0, y: 60, width: 390, height: 260)) + [
            SceneElement(snow, SceneColor(0xFFFFFF, opacity: 0.7), still: true),
            SceneElement(SceneArt.ridge(seed: 1202, baseline: 600, height: 70, roughness: 0.55, bottom: 640), gradient: [SceneColor(0x8A9ACB), SceneColor(0x5A6A9E)]),
            SceneElement(SceneArt.pines(seed: 1203, x: -10...400, base: 640, height: 30...56, spacing: 14), gradient: [SceneColor(0x2E4470), SceneColor(0x1E2E52)]),
            SceneElement(ScenePath.group([ScenePath.rect(10, 606, 60, 50), ScenePath.rect(320, 612, 60, 44)]), gradient: [SceneColor(0x4A3A5A), SceneColor(0x2E2440)]),
            SceneElement(ScenePath.group([ScenePath.polygon([(4, 608), (40, 580), (76, 608)]), ScenePath.polygon([(314, 614), (350, 588), (386, 614)])]),
                         gradient: [SceneColor(0x6B3E4E), SceneColor(0x3E2434)]),
            SceneElement(ScenePath.group([ScenePath.polygon([(1, 610), (40, 576), (79, 610), (72, 612), (40, 584), (8, 612)]),
                                          ScenePath.polygon([(311, 616), (350, 584), (389, 616), (382, 618), (350, 592), (318, 618)])]), SceneColor(0xF4F7FD)),
            SceneElement(SceneArt.hills([(-30, 660), (120, 640), (270, 650), (420, 636)]), gradient: [SceneColor(0xF4F7FD), SceneColor(0xCAD4EC)]),
            SceneElement(ScenePath.rect(0, 672, 390, 28), gradient: [SceneColor(0xEEF2FB), SceneColor(0xD2DAEE)]),
            SceneElement(ScenePath.ellipse(120, 662, 150, 16), SceneColor(0xA9B6D8, opacity: 0.5), blur: 3),
            SceneElement(ScenePath.rect(183, 640, 24, 40), gradient: [SceneColor(0x6A4430), SceneColor(0x3E2618)])
        ]
        background += zip(tiers, treeTiers).map { SceneElement($0.1.body, gradient: [SceneColor($0.0.color == 0x174A2F ? 0x2A7048 : 0x33804F), SceneColor($0.0.color)]) }
        background.append(SceneElement(ScenePath.group(treeTiers.map(\.snow)), SceneColor(0xF4F7FD, opacity: 0.9)))
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
            month: 12, title: "크리스마스트리", sky: [SceneColor(0x070E28), SceneColor(0x16234E), SceneColor(0x34457E), SceneColor(0x6A7AAE)],
            background: background, lights: lights,
            completion: [
                SceneElement(ScenePath.circle(195, 290, 30), SceneColor(0xFFE9A0, opacity: 0.06)),
                SceneElement(ScenePath.circle(195, 290, 21), SceneColor(0xFFE9A0, opacity: 0.1)),
                SceneElement(ScenePath.group([ScenePath.rect(26, 620, 12, 12), ScenePath.rect(44, 620, 12, 12), ScenePath.rect(336, 624, 12, 12), ScenePath.rect(354, 624, 12, 12)]),
                             SceneColor(0xFFD27A), glow: 8),
                SceneElement(bigSnow, SceneColor(0xFFFFFF, opacity: 0.9), still: true)
            ] + gifts.map { SceneElement(ScenePath.rect($0.0, $0.1, $0.2, $0.3, corner: 2), gradient: [SceneColor($0.4), SceneColor($0.4).darker(0.75)]) } + [
                SceneElement(ribbons, SceneColor(0xFFD43B), lineWidth: 2.2),
                SceneElement(bows, SceneColor(0xFFD43B))
            ],
            ambience: ambience(for: 12),
            keepsLastLightLast: true
        )
    }()

    // MARK: - Layout helpers

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
