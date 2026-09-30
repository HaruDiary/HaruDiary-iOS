import Foundation
import UserNotifications

@MainActor
final class UserNotificationReminderScheduler: ReminderScheduling {
    /// Earlier versions scheduled one repeating reminder per weekday under these identifiers.
    private static let legacyIdentifiers = Set((1...7).map(String.init))

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func replace(with requests: [ReminderRequest]) async {
        let old = await center.pendingNotificationRequests().map(\.identifier).filter {
            $0.hasPrefix(ReminderRequest.identifierPrefix) || Self.legacyIdentifiers.contains($0)
        }
        center.removePendingNotificationRequests(withIdentifiers: old)
        var failed = 0
        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: request.fireDate, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
            } catch {
                failed += 1
            }
        }
        // Counts only.
        print("Diary reminders scheduled: \(requests.count - failed), failed: \(failed)")
    }
}
