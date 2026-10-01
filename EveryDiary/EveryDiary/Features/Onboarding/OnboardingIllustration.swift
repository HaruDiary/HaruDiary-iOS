import SwiftUI

/// The picture of an onboarding page: a small mock of what the page tells about, drawn with the app's own
/// colours and pieces, so it follows light and dark mode. Drawn on a fixed canvas and scaled to the space given.
struct OnboardingIllustration: View {
    let page: OnboardingPage

    private static let canvas = CGSize(width: 300, height: 270)

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / Self.canvas.width, geometry.size.height / Self.canvas.height)
            content
                .frame(width: Self.canvas.width, height: Self.canvas.height)
                .scaleEffect(scale)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // The mock's own texts are part of the picture: they keep their size and are not read aloud.
        .dynamicTypeSize(.medium)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .record: record
        case .calendar: calendar
        case .memories: memories
        case .journey: journey
        case .keep: keep
        }
    }

    // MARK: - Pieces

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(DiaryTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    /// A line of writing that is not meant to be read.
    private func line(_ width: CGFloat, opacity: Double = 0.28) -> some View {
        Capsule().fill(DiaryTheme.Colors.secondaryText.opacity(opacity)).frame(width: width, height: 7)
    }

    private func chip<Icon: View>(_ text: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 5) {
            icon()
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(DiaryTheme.Colors.brand)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DiaryTheme.Colors.brand.opacity(0.12), in: Capsule())
    }

    private func mood(_ name: String, size: CGFloat) -> some View {
        Image(name).resizable().scaledToFit().frame(width: size, height: size)
    }

    private func photo(_ colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 56, height: 56)
    }

    // MARK: - Pages

    /// Writing: date, mood and weather, text, photos, and a question to start from.
    private var record: some View {
        ZStack(alignment: .topTrailing) {
            card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("10월 1일 목요일")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DiaryTheme.Colors.secondaryText)
                    HStack(spacing: 8) {
                        chip("신남") { mood("Grinning face", size: 16) }
                        chip("맑음") { DiaryWeatherIcon(name: "u_sun", size: 16) }
                    }
                    Text("공원을 걸은 날")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DiaryTheme.Colors.text)
                    VStack(alignment: .leading, spacing: 8) {
                        line(210)
                        line(180)
                        line(120)
                    }
                    HStack(spacing: 8) {
                        photo([Color(red: 0.55, green: 0.78, blue: 0.95), Color(red: 0.45, green: 0.62, blue: 0.9)])
                        photo([Color(red: 0.98, green: 0.76, blue: 0.5), Color(red: 0.95, green: 0.55, blue: 0.5)])
                        photo([Color(red: 0.6, green: 0.85, blue: 0.62), Color(red: 0.35, green: 0.68, blue: 0.55)])
                    }
                }
                .frame(width: 216, alignment: .leading)
            }
            .padding(.top, 26)
            .padding(.trailing, 26)

            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").font(.system(size: 12))
                Text("오늘 고마웠던 일은?").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(DiaryTheme.Colors.onBrand)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DiaryTheme.Colors.brand, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
    }

    /// The calendar with a mood under the days written, and the month's moods.
    private var calendar: some View {
        let moods: [Int: String] = [2: "Grinning face", 4: "Neutral face", 5: "Smiling face with smiling eyes",
                                    9: "Sleeping face", 11: "Grinning face", 12: "Smiling face with smiling eyes"]
        return card {
            VStack(spacing: 12) {
                Text("2026년 10월")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DiaryTheme.Colors.brand)
                VStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { column in
                                let day = row * 7 + column + 1
                                VStack(spacing: 3) {
                                    Text("\(day)")
                                        .font(.system(size: 12, weight: day == 5 ? .bold : .regular))
                                        .foregroundStyle(day == 5 ? DiaryTheme.Colors.onBrand
                                                         : column == 0 ? DiaryTheme.Colors.holiday
                                                         : column == 6 ? DiaryTheme.Colors.saturday : DiaryTheme.Colors.text)
                                        .frame(width: 24, height: 24)
                                        .background { if day == 5 { Circle().fill(DiaryTheme.Colors.brand) } }
                                    Group {
                                        if let name = moods[day] { mood(name, size: 14) } else { Color.clear }
                                    }
                                    .frame(width: 14, height: 14)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                Divider()
                VStack(spacing: 8) {
                    moodBar("Grinning face", share: 0.8)
                    moodBar("Smiling face with smiling eyes", share: 0.55)
                    moodBar("Sleeping face", share: 0.25)
                }
            }
            .frame(width: 230)
        }
    }

    private func moodBar(_ name: String, share: CGFloat) -> some View {
        HStack(spacing: 10) {
            mood(name, size: 18)
            Capsule().fill(DiaryTheme.Colors.selection.opacity(0.5))
                .frame(height: 7)
                .overlay(alignment: .leading) {
                    Capsule().fill(DiaryTheme.Colors.brand.opacity(0.7)).frame(width: 180 * share, height: 7)
                }
                .frame(width: 180)
        }
    }

    /// A diary from a year ago and the search.
    private var memories: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .semibold))
                Text("공원").font(.system(size: 13, weight: .medium)).foregroundStyle(DiaryTheme.Colors.text)
                Spacer()
            }
            .foregroundStyle(DiaryTheme.Colors.secondaryText)
            .padding(.horizontal, 14)
            .frame(width: 250, height: 38)
            .background(DiaryTheme.Colors.selection.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 13, weight: .semibold))
                Text("1년 전 오늘").font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(DiaryTheme.Colors.brand)

            card {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 2) {
                        Text("1").font(.system(size: 18, weight: .bold)).foregroundStyle(DiaryTheme.Colors.text)
                        Text("수").font(.system(size: 11, weight: .medium)).foregroundStyle(DiaryTheme.Colors.secondaryText)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("공원 산책")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DiaryTheme.Colors.text)
                        line(120)
                        line(90)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 6) {
                        mood("Smiling face with smiling eyes", size: 18)
                        photo([Color(red: 0.6, green: 0.85, blue: 0.62), Color(red: 0.35, green: 0.68, blue: 0.55)])
                            .scaleEffect(0.8, anchor: .topTrailing)
                            .frame(width: 45, height: 45)
                    }
                }
                .frame(width: 218)
            }
        }
    }

    /// The month's picture, lit for the days written. The picture has its own colours in both modes.
    private var journey: some View {
        JourneySceneView(scene: JourneySceneCatalog.scene(for: 10), year: 2026, litCount: 18, slotCount: 31)
            .frame(width: 190, height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
            .overlay(alignment: .bottom) {
                Text("31일 중 18일")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DiaryTheme.Colors.onBrand)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(DiaryTheme.Colors.brand, in: Capsule())
                    .offset(y: 14)
            }
            .padding(.bottom, 14)
    }

    /// The diary kept safe: the account, the app lock and the ways to take it along.
    private var keep: some View {
        VStack(spacing: 18) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 74))
                    .foregroundStyle(DiaryTheme.Colors.brand)
                    .frame(width: 150, height: 150)
                    .background(DiaryTheme.Colors.surface, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DiaryTheme.Colors.onBrand)
                    .frame(width: 52, height: 52)
                    .background(DiaryTheme.Colors.brand, in: Circle())
                    .overlay { Circle().strokeBorder(DiaryTheme.Colors.onboardingBackground, lineWidth: 4) }
            }
            HStack(spacing: 8) {
                chip("앱 잠금") { Image(systemName: "faceid").font(.system(size: 12, weight: .semibold)) }
                chip("내보내기") { Image(systemName: "square.and.arrow.up").font(.system(size: 12, weight: .semibold)) }
                chip("큰 글자") { Image(systemName: "textformat.size").font(.system(size: 12, weight: .semibold)) }
            }
        }
    }
}

#if DEBUG
#Preview("온보딩 그림") {
    ScrollView {
        VStack(spacing: 24) {
            ForEach(OnboardingPage.allCases) { page in
                OnboardingIllustration(page: page).frame(height: 270)
            }
        }
        .padding()
    }
    .background(DiaryTheme.Colors.onboardingBackground)
}
#endif
