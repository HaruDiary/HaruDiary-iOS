import CoreGraphics
import Foundation

/// The twelve monthly pictures. Coordinates use `JourneyScene.canvas` (390 × 700, y grows downward).
/// Light order is the order in which diary days fill the picture.
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

    // MARK: 1월 · 눈 내린 마을 — house windows light up one by one

    static let snowyVillage: JourneyScene = {
        var random = SceneRandom(seed: 101)
        let snow = ScenePath.group((0..<45).map { _ in
            ScenePath.circle(random.next(0...390), random.next(90...640), random.next(1...2.2))
        })
        let houses: [(x: CGFloat, width: CGFloat, height: CGFloat, base: CGFloat, columns: Int, rows: Int)] = [
            (18, 70, 84, 668, 3, 2), (100, 60, 66, 676, 2, 2), (172, 78, 104, 664, 3, 3), (262, 58, 76, 672, 2, 3), (330, 52, 92, 666, 2, 3)
        ]
        var background: [SceneElement] = [
            SceneElement(ScenePath.circle(300, 190, 28), SceneColor(0xF4F1DE)),
            SceneElement(snow, SceneColor(0xFFFFFF, opacity: 0.75)),
            SceneElement(ScenePath.ellipse(-120, 560, 640, 300), SceneColor(0xB9C4DE)),
            SceneElement(ScenePath.ellipse(-60, 650, 510, 140), SceneColor(0xEEF2FA)),
            SceneElement(ScenePath.rect(0, 672, 390, 28), SceneColor(0xEEF2FA))
        ]
        var lights: [SceneLight] = []
        for house in houses {
            let top = house.base - house.height
            let roof = house.width * 0.45
            background.append(SceneElement(ScenePath.rect(house.x + house.width * 0.65, top - roof * 0.9, 9, roof * 0.7), SceneColor(0x2A2440)))
            background.append(SceneElement(ScenePath.rect(house.x, top, house.width, house.height), SceneColor(0x3A3350)))
            let roofLine = [(house.x - 7, top + 1), (house.x + house.width / 2, top - roof), (house.x + house.width + 7, top + 1)]
            background.append(SceneElement(ScenePath.polygon(roofLine), SceneColor(0x2A2440)))
            background.append(SceneElement(ScenePath.line(roofLine), SceneColor(0xF4F7FD), lineWidth: 5))
            let gap = (house.width - CGFloat(house.columns) * 10) / CGFloat(house.columns + 1)
            for row in 0..<house.rows {
                for column in 0..<house.columns {
                    let x = house.x + gap + CGFloat(column) * (10 + gap)
                    let y = house.base - 26 - CGFloat(row) * 22
                    lights.append(SceneLight(ScenePath.rect(x, y, 10, 12, corner: 1.5), on: SceneColor(0xFFD27A), off: SceneColor(0x262040), glow: 6))
                }
            }
        }
        return JourneyScene(month: 1, title: "눈 내린 마을", sky: [SceneColor(0x0E1B3D), SceneColor(0x3B4F7F), SceneColor(0x7C8DB5)],
                            background: background, lights: lights)
    }()

    // MARK: 2월 · 설날 청사초롱 — lanterns along strings over hanok roofs

    static let newYearLanterns: JourneyScene = {
        var background: [SceneElement] = [
            SceneElement(ScenePath.rect(20, 600, 150, 100), SceneColor(0x2E2146)),
            SceneElement(ScenePath.polygon([(0, 588), (20, 602), (170, 602), (190, 588), (160, 568), (30, 568)]), SceneColor(0x1A1230)),
            SceneElement(ScenePath.rect(212, 592, 166, 108), SceneColor(0x2E2146)),
            SceneElement(ScenePath.polygon([(192, 578), (212, 594), (378, 594), (398, 578), (362, 556), (246, 556)]), SceneColor(0x1A1230)),
            SceneElement(ScenePath.rect(0, 680, 390, 20), SceneColor(0x20162F))
        ]
        var lights: [SceneLight] = []
        let red = SceneColor(0xFF5E6C), blue = SceneColor(0x5B8CFF), off = SceneColor(0x3B2B57)
        func lantern(_ point: CGPoint) -> CGPath {
            ScenePath.group([ScenePath.rect(point.x - 5, point.y + 6, 10, 3), ScenePath.rect(point.x - 8, point.y + 8, 16, 22, corner: 6)])
        }
        for (row, (y, count)) in [(CGFloat(250), 9), (350, 10), (450, 9)].enumerated() {
            let start = CGPoint(x: -10, y: y), end = CGPoint(x: 400, y: y - 10), control = CGPoint(x: 195, y: y + 60)
            background.append(SceneElement(ScenePath.curve(from: start, to: end, control: control), SceneColor(0x8C7AA8), lineWidth: 1.2))
            for index in 0..<count {
                let point = ScenePath.point(onCurveFrom: start, to: end, control: control, at: (CGFloat(index) + 0.5) / CGFloat(count))
                background.append(SceneElement(ScenePath.line([(point.x, point.y), (point.x, point.y + 7)]), SceneColor(0x8C7AA8), lineWidth: 1))
                lights.append(SceneLight(lantern(point), on: (index + row).isMultiple(of: 2) ? red : blue, off: off, glow: 10))
            }
        }
        // 29 February: a lantern under the eaves of the first house.
        lights.append(SceneLight(lantern(CGPoint(x: 95, y: 596)), on: red, off: off, glow: 10))
        return JourneyScene(month: 2, title: "설날 청사초롱", sky: [SceneColor(0x1C1440), SceneColor(0x4B2E6B), SceneColor(0xC9738A)],
                            background: background, lights: lights)
    }()

    // MARK: 3월 · 봄 들판 — buds bloom into flowers

    static let springMeadow: JourneyScene = {
        let points = scatter(count: 31, seed: 303, x: 16...374, y: 582...688, minimumDistance: 24)
        let colors = [SceneColor(0xFFD95A), SceneColor(0xFF9EB5), SceneColor(0xFFFFFF), SceneColor(0xC9A6FF)]
        let stems = ScenePath.group(points.map { ScenePath.line([($0.x, $0.y), ($0.x, $0.y + 11)]) })
        let lights = points.enumerated().map { index, point -> SceneLight in
            let petals = (0..<5).map { petal -> CGPath in
                let angle = CGFloat(petal) * 2 * .pi / 5 - .pi / 2
                return ScenePath.circle(point.x + cos(angle) * 5, point.y + sin(angle) * 5, 4.5)
            }
            return SceneLight(ScenePath.group(petals), on: colors[index % colors.count], off: SceneColor(0x3F7D3A),
                              offPath: ScenePath.ellipse(point.x - 3, point.y - 5, 6, 9), glow: 3)
        }
        return JourneyScene(
            month: 3, title: "봄 들판", sky: [SceneColor(0x2E5E8C), SceneColor(0x6FA8C4), SceneColor(0xCFE8C0)],
            background: [
                SceneElement(ScenePath.circle(80, 300, 26), SceneColor(0xFFF4C9, opacity: 0.9)),
                SceneElement(ScenePath.group([ScenePath.ellipse(220, 232, 96, 26), ScenePath.ellipse(250, 214, 58, 32)]), SceneColor(0xFFFFFF, opacity: 0.7)),
                SceneElement(ScenePath.ellipse(-120, 540, 420, 260), SceneColor(0x8CC26F)),
                SceneElement(ScenePath.ellipse(140, 555, 400, 240), SceneColor(0x74B060)),
                SceneElement(ScenePath.ellipse(-50, 596, 490, 180), SceneColor(0x5E9A50)),
                SceneElement(ScenePath.rect(0, 650, 390, 50), SceneColor(0x5E9A50)),
                SceneElement(stems, SceneColor(0x3F7D3A), lineWidth: 1.5)
            ],
            lights: lights
        )
    }()

    // MARK: 4월 · 벚꽃나무 — blossoms open from the middle of the tree outward

    static let cherryBlossom: JourneyScene = {
        var random = SceneRandom(seed: 404)
        let petals = ScenePath.group((0..<14).map { _ in ScenePath.ellipse(random.next(10...380), random.next(520...690), 4, 3) })
        let colors = [SceneColor(0xFFC4D6), SceneColor(0xFFE1EA), SceneColor(0xFF9DBA)]
        let lights = sunflower(count: 30, center: CGPoint(x: 195, y: 420), radiusX: 150, radiusY: 105).enumerated().map { index, point in
            SceneLight(ScenePath.group([ScenePath.circle(point.x, point.y, 14), ScenePath.circle(point.x - 9, point.y + 6, 9), ScenePath.circle(point.x + 9, point.y + 5, 9)]),
                       on: colors[index % colors.count], off: SceneColor(0x6B4A66), offPath: ScenePath.circle(point.x, point.y, 5), glow: 5)
        }
        return JourneyScene(
            month: 4, title: "벚꽃나무", sky: [SceneColor(0x3A2552), SceneColor(0x9E5A8A), SceneColor(0xF0B3C4)],
            background: [SceneElement(ScenePath.ellipse(-80, 630, 550, 160), SceneColor(0x5A3A5C)),
                         SceneElement(ScenePath.rect(0, 670, 390, 30), SceneColor(0x5A3A5C))]
                + tree(color: SceneColor(0x4A2C3A))
                + [SceneElement(petals, SceneColor(0xFFC4D6, opacity: 0.7))],
            lights: lights
        )
    }()

    // MARK: 5월 · 연등 — rows of lotus lanterns over a temple

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
                let top = y + 2
                let lantern = ScenePath.group([
                    ScenePath.polygon([(x - 11, top + 10), (x - 6, top), (x, top + 8), (x + 6, top), (x + 11, top + 10)]),
                    ScenePath.ellipse(x - 11, top + 6, 22, 20),
                    ScenePath.rect(x - 1, top + 26, 2, 7)
                ])
                lights.append(SceneLight(lantern, on: colors[(index + row * 2) % colors.count], off: SceneColor(0x262A55), glow: 9))
            }
        }
        return JourneyScene(month: 5, title: "연등", sky: [SceneColor(0x0D1233), SceneColor(0x1F2A5C), SceneColor(0x3B3D7A)],
                            background: background, lights: lights)
    }()

    // MARK: 6월 · 반딧불이 숲 — fireflies gather over the forest

    static let fireflyForest: JourneyScene = {
        var random = SceneRandom(seed: 606)
        var background: [SceneElement] = [
            SceneElement(ScenePath.circle(310, 200, 34), SceneColor(0xF3F0D0, opacity: 0.08)),
            SceneElement(ScenePath.circle(310, 200, 17), SceneColor(0xF3F0D0, opacity: 0.9))
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
            SceneLight(ScenePath.circle(point.x, point.y, 3), on: SceneColor(0xE9FF8C), off: SceneColor(0x1D4A3B),
                       offPath: ScenePath.circle(point.x, point.y, 1.5), glow: 10)
        }
        return JourneyScene(month: 6, title: "반딧불이 숲", sky: [SceneColor(0x03110D), SceneColor(0x0A2A21), SceneColor(0x174537)],
                            background: background, lights: lights)
    }()

    // MARK: 7월 · 여름 바다 — stars come out over the lighthouse

    static let summerSea: JourneyScene = {
        let reflection = ScenePath.group([ScenePath.ellipse(62, 574, 36, 3), ScenePath.ellipse(68, 594, 24, 3), ScenePath.ellipse(72, 616, 16, 3), ScenePath.ellipse(76, 640, 9, 2)])
        let background: [SceneElement] = [
            SceneElement(ScenePath.circle(80, 230, 24), SceneColor(0xF8F4DC)),
            SceneElement(ScenePath.rect(0, 560, 390, 140), SceneColor(0x0A2342)),
            SceneElement(reflection, SceneColor(0xF8F4DC, opacity: 0.35)),
            SceneElement(ScenePath.polygon([(330, 463), (190, 425), (190, 480)]), SceneColor(0xFFF2A8, opacity: 0.12)),
            SceneElement(ScenePath.polygon([(262, 700), (270, 600), (300, 570), (360, 564), (390, 580), (390, 700)]), SceneColor(0x07152C)),
            SceneElement(ScenePath.polygon([(318, 568), (322, 470), (338, 470), (342, 568)]), SceneColor(0xE8E6F0)),
            SceneElement(ScenePath.group([ScenePath.rect(320, 500, 20, 10), ScenePath.rect(319, 530, 22, 10)]), SceneColor(0xD9534F)),
            SceneElement(ScenePath.rect(316, 455, 28, 16), SceneColor(0x2A2F4A)),
            SceneElement(ScenePath.polygon([(314, 455), (330, 440), (346, 455)]), SceneColor(0xD9534F)),
            SceneElement(ScenePath.circle(330, 463, 5), SceneColor(0xFFF2A8))
        ]
        let points = scatter(count: 31, seed: 707, x: 12...378, y: 110...520, minimumDistance: 38) { point in
            hypot(point.x - 80, point.y - 230) > 44 && !(point.x > 296 && point.y > 424)
        }
        var random = SceneRandom(seed: 717)
        let lights = points.map { point -> SceneLight in
            let size = random.next(5...8)
            return SceneLight(ScenePath.star(point.x, point.y, outer: size, inner: size * 0.3, points: 4), on: SceneColor(0xFFF6C8), off: SceneColor(0x2A3D6E),
                              offPath: ScenePath.circle(point.x, point.y, 1.3), glow: 6)
        }
        return JourneyScene(month: 7, title: "여름 바다", sky: [SceneColor(0x020617), SceneColor(0x0B1F4A), SceneColor(0x1E4478)],
                            background: background, lights: lights)
    }()

    // MARK: 8월 · 불꽃놀이 — fireworks burst over the river

    static let fireworks: JourneyScene = {
        let widths: [CGFloat] = [40, 30, 50, 25, 45, 35, 60, 30, 40, 35]
        let heights: [CGFloat] = [70, 110, 60, 140, 90, 75, 120, 55, 100, 80]
        var x: CGFloat = 0
        var skyline: [CGPath] = []
        for (width, height) in zip(widths, heights) {
            skyline.append(ScenePath.rect(x, 640 - height, width + 1, height))
            x += width
        }
        let colors = [SceneColor(0xFF6B6B), SceneColor(0xFFD93D), SceneColor(0x6BCBFF), SceneColor(0xB388FF), SceneColor(0x7CFFB2), SceneColor(0xFF9F68)]
        var random = SceneRandom(seed: 818)
        let lights = scatter(count: 31, seed: 808, x: 30...360, y: 120...460, minimumDistance: 44).enumerated().map { index, point -> SceneLight in
            let radius = random.next(14...26)
            let rays = (0..<12).map { ray -> CGPath in
                let angle = CGFloat(ray) * .pi / 6
                return ScenePath.line([(point.x + cos(angle) * radius * 0.35, point.y + sin(angle) * radius * 0.35),
                                       (point.x + cos(angle) * radius, point.y + sin(angle) * radius)])
            }
            return SceneLight(ScenePath.group(rays + [ScenePath.circle(point.x, point.y, 1.5)]), on: colors[index % colors.count], off: SceneColor(0x2E2560),
                              offPath: ScenePath.circle(point.x, point.y, 1), glow: 8, lineWidth: 2)
        }
        return JourneyScene(
            month: 8, title: "불꽃놀이", sky: [SceneColor(0x07071C), SceneColor(0x17123F), SceneColor(0x33205A)],
            background: [SceneElement(ScenePath.group(skyline), SceneColor(0x0B0A1F)),
                         SceneElement(ScenePath.rect(0, 640, 390, 60), SceneColor(0x0E1030)),
                         SceneElement(ScenePath.line([(0, 612), (390, 612)]), SceneColor(0x1B1840), lineWidth: 4)],
            lights: lights
        )
    }()

    // MARK: 9월 · 한가위 풍등 — sky lanterns rise from the village

    static let harvestMoon: JourneyScene = {
        let roofs = ScenePath.group([(CGFloat(10), CGFloat(80)), (110, 90), (220, 76), (300, 84)].map { x, width in
            ScenePath.polygon([(x - 8, 646), (x + 4, 632), (x + width * 0.2, 620), (x + width * 0.8, 620), (x + width - 4, 632), (x + width + 8, 646)])
        })
        let houses = ScenePath.group([(CGFloat(14), CGFloat(72)), (116, 80), (224, 68), (306, 76)].map { x, width in ScenePath.rect(x, 644, width, 56) })
        let points = scatter(count: 30, seed: 909, x: 20...370, y: 190...600, minimumDistance: 34) { point in
            hypot(point.x - 290, point.y - 200) > 72
        }.sorted { $0.y > $1.y }
        let lights = points.map { point -> SceneLight in
            let s = 0.6 + 0.6 * (point.y - 190) / 410
            return SceneLight(ScenePath.polygon([(point.x - 5 * s, point.y - 9 * s), (point.x + 5 * s, point.y - 9 * s), (point.x + 7 * s, point.y + 9 * s), (point.x - 7 * s, point.y + 9 * s)]),
                              on: SceneColor(0xFFB65C), off: SceneColor(0x33305E), glow: 10)
        }
        return JourneyScene(
            month: 9, title: "한가위 풍등", sky: [SceneColor(0x10183A), SceneColor(0x2B2D63), SceneColor(0x74507E)],
            background: [
                SceneElement(ScenePath.circle(290, 200, 70), SceneColor(0xFFF1C1, opacity: 0.12)),
                SceneElement(ScenePath.circle(290, 200, 48), SceneColor(0xFFF1C1)),
                SceneElement(ScenePath.ellipse(-100, 596, 380, 200), SceneColor(0x1E1C3E)),
                SceneElement(ScenePath.ellipse(160, 590, 360, 220), SceneColor(0x1A1836)),
                SceneElement(houses, SceneColor(0x1A1633)),
                SceneElement(roofs, SceneColor(0x120F28))
            ],
            lights: lights
        )
    }()

    // MARK: 10월 · 단풍 — leaves turn red from the edge of the tree inward

    static let autumnMaple: JourneyScene = {
        let colors = [SceneColor(0xE8452C), SceneColor(0xF28C28), SceneColor(0xF6C343), SceneColor(0xC2362B)]
        var random = SceneRandom(seed: 1010)
        let fallen = ScenePath.group((0..<10).map { _ in
            ScenePath.star(random.next(20...370), random.next(672...694), outer: 6, inner: 3, points: 5, rotation: random.next(0...6))
        })
        let points = Array(sunflower(count: 31, center: CGPoint(x: 195, y: 420), radiusX: 150, radiusY: 110).reversed())
        let lights = points.enumerated().map { index, point in
            SceneLight(ScenePath.star(point.x, point.y, outer: 16, inner: 7.5, points: 5), on: colors[index % colors.count], off: SceneColor(0x4E6B3A))
        }
        return JourneyScene(
            month: 10, title: "단풍", sky: [SceneColor(0x2A1A3D), SceneColor(0x9A4E3E), SceneColor(0xF0A65A)],
            background: [SceneElement(ScenePath.circle(300, 590, 40), SceneColor(0xFFD28A, opacity: 0.8)),
                         SceneElement(ScenePath.ellipse(-80, 600, 300, 200), SceneColor(0x6B3A2E)),
                         SceneElement(ScenePath.ellipse(180, 610, 320, 200), SceneColor(0x5A2F26)),
                         SceneElement(ScenePath.rect(0, 660, 390, 40), SceneColor(0x4A261F))]
                + tree(color: SceneColor(0x3B2320))
                + [SceneElement(fallen, SceneColor(0xE8452C, opacity: 0.85))],
            lights: lights
        )
    }()

    // MARK: 11월 · 도시의 밤 — the original apartment windows

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
                    lights.append(SceneLight(ScenePath.rect(x, y, 10, 22), on: SceneColor(0xFFEB4D), off: SceneColor(0x555555), glow: 4))
                }
            }
        }
        return JourneyScene(month: 11, title: "도시의 밤", sky: [SceneColor(0x7D2493), SceneColor(0xB4419A), SceneColor(0xEA5DA2)],
                            background: [SceneElement(back, SceneColor(0x555555)), SceneElement(front, SceneColor(0x000000))], lights: lights)
    }()

    // MARK: 12월 · 크리스마스트리 — bulbs light up, and the star on top comes last

    static let christmasTree: JourneyScene = {
        var random = SceneRandom(seed: 1212)
        let snow = ScenePath.group((0..<40).map { _ in ScenePath.circle(random.next(0...390), random.next(100...640), random.next(1...2)) })
        let tiers: [(tip: CGFloat, base: CGFloat, half: CGFloat, color: UInt32)] = [
            (490, 645, 120, 0x174A2F), (420, 560, 100, 0x1F5B3A), (350, 480, 80, 0x174A2F), (300, 400, 55, 0x1F5B3A)
        ]
        var background: [SceneElement] = [
            SceneElement(snow, SceneColor(0xFFFFFF, opacity: 0.7)),
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
            for (index, point) in points.enumerated() {
                lights.append(SceneLight(ScenePath.circle(point.x, point.y, 5), on: colors[(lights.count + index) % colors.count], off: SceneColor(0x0E3322), glow: 7))
            }
        }
        lights.append(SceneLight(ScenePath.star(195, 292, outer: 15, inner: 6.5, points: 5), on: SceneColor(0xFFD95A), off: SceneColor(0x3A4A3A), glow: 12))
        return JourneyScene(month: 12, title: "크리스마스트리", sky: [SceneColor(0x0B1430), SceneColor(0x1D2B5A), SceneColor(0x3E4E86)],
                            background: background, lights: lights)
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
