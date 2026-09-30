import Foundation

/// Reminder settings in UserDefaults under the keys earlier versions used, so existing settings carry over.
final class UserDefaultsReminderStore: ReminderSettingsStore {
    private static let isOnKey = "isSwitchOn"
    private static let timeKey = "selectedTime"
    /// Seven Bools, Sunday first.
    private static let daysKey = "selectedDays"
    private static let skipKey = "ReminderSkipWhenWritten"
    private static let writtenDayKey = "ReminderWrittenDay"

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    var settings: ReminderSettings {
        get {
            var settings = ReminderSettings()
            settings.isOn = defaults.bool(forKey: Self.isOnKey)
            if let time = defaults.object(forKey: Self.timeKey) as? Date {
                settings.hour = calendar.component(.hour, from: time)
                settings.minute = calendar.component(.minute, from: time)
            }
            if let days = defaults.array(forKey: Self.daysKey) as? [Bool], days.count == 7 {
                settings.weekdays = Set(days.indices.filter { days[$0] }.map { $0 + 1 })
            }
            if defaults.object(forKey: Self.skipKey) != nil {
                settings.skipWhenWritten = defaults.bool(forKey: Self.skipKey)
            }
            return settings
        }
        set {
            defaults.set(newValue.isOn, forKey: Self.isOnKey)
            let time = calendar.date(bySettingHour: newValue.hour, minute: newValue.minute, second: 0, of: Date())
            defaults.set(time, forKey: Self.timeKey)
            defaults.set((1...7).map { newValue.weekdays.contains($0) }, forKey: Self.daysKey)
            defaults.set(newValue.skipWhenWritten, forKey: Self.skipKey)
        }
    }

    var writtenDay: String? {
        get { defaults.string(forKey: Self.writtenDayKey) }
        set { defaults.set(newValue, forKey: Self.writtenDayKey) }
    }
}
