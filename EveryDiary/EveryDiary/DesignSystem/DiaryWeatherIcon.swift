import SwiftUI

/// Colored weather icon for a stored weather value ("u_sun", ...).
/// Stored values are unchanged; unknown values fall back to the original monochrome asset.
struct DiaryWeatherIcon: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let style = Self.styles[name] {
                symbol(style)
            } else {
                Image(name).resizable().scaledToFit()
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func symbol(_ style: Style) -> some View {
        let image = Image(systemName: style.symbol).resizable().scaledToFit()
        switch style.colors.count {
        case 0: image.symbolRenderingMode(.multicolor)
        case 1: image.foregroundStyle(style.colors[0])
        case 2: image.symbolRenderingMode(.palette).foregroundStyle(style.colors[0], style.colors[1])
        default: image.symbolRenderingMode(.palette).foregroundStyle(style.colors[0], style.colors[1], style.colors[2])
        }
    }

    private struct Style {
        let symbol: String
        /// Palette layers in SF Symbol order; empty uses the symbol's own multicolor rendering.
        let colors: [Color]
    }

    private static let sun = Color.orange
    private static let cloud = Color(.systemGray2)
    private static let rain = Color.blue

    // Keys are the values stored by the editor's weather picker (DateConditionSelectVC).
    private static let styles: [String: Style] = [
        "u_sun": Style(symbol: "sun.max.fill", colors: [sun]),
        "u_cloud-sun": Style(symbol: "cloud.sun.fill", colors: [cloud, sun]),
        "u_clouds": Style(symbol: "smoke.fill", colors: [cloud]),
        "fi_wind": Style(symbol: "wind", colors: [Color.teal]),
        "u_cloud-showers-heavy": Style(symbol: "cloud.heavyrain.fill", colors: [cloud, rain]),
        "u_moon": Style(symbol: "moon.fill", colors: [Color.yellow]),
        "u_cloud-moon": Style(symbol: "cloud.moon.fill", colors: [cloud, Color.yellow]),
        "u_rainbow": Style(symbol: "rainbow", colors: []),
        "u_snowflake": Style(symbol: "snowflake", colors: [Color.cyan]),
        "u_thunderstorm": Style(symbol: "cloud.bolt.rain.fill", colors: [cloud, sun, rain]),
    ]
}

#if DEBUG
#Preview("날씨 아이콘") {
    HStack(spacing: 12) {
        ForEach(["u_sun", "u_cloud-sun", "u_clouds", "fi_wind", "u_cloud-showers-heavy",
                 "u_moon", "u_cloud-moon", "u_rainbow", "u_snowflake", "u_thunderstorm"], id: \.self) {
            DiaryWeatherIcon(name: $0, size: 28)
        }
    }
    .padding()
}
#endif
