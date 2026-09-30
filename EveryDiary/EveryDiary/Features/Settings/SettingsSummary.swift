import Foundation

/// The values shown at the right of the settings rows (mockup 16), e.g. "매일 오후 9:00" or "암호 · Face ID".
enum SettingsSummary {
    static func reminder(_ settings: ReminderSettings, calendar: Calendar) -> String {
        guard settings.isOn else { return "꺼짐" }
        guard !settings.weekdays.isEmpty else { return "요일 없음" }
        let time = calendar.date(bySettingHour: settings.hour, minute: settings.minute, second: 0, of: Date()) ?? Date()
        var style = Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "ko_KR"))
        style.timeZone = calendar.timeZone
        return "\(ReminderPlan.summary(of: settings.weekdays)) \(time.formatted(style))"
    }

    static func lock(_ mode: AppLock.Mode, biometry: Biometry) -> String {
        switch mode {
        case .off: return "꺼짐"
        case .legacyBiometrics: return biometry.name ?? "켜짐"
        case .passcode(let biometrics):
            guard biometrics, let name = biometry.name else { return "암호" }
            return "암호 · \(name)"
        }
    }

    /// "버전 2.0 (15)" from the app's Info.plist values.
    static func version(short: String?, build: String?) -> String {
        guard let short else { return "" }
        guard let build, !build.isEmpty, build != short else { return "버전 \(short)" }
        return "버전 \(short) (\(build))"
    }
}
