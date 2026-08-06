import Foundation
import UserNotifications

/// Manages the ONE daily morning brief notification.
/// Philosophy: maximum 1 push per day. Only push when there's something worth knowing.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Request notification permission
    func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Schedule the daily morning brief notification (fires at 8:00 AM local time)
    func scheduleMorningBrief(triggerOnTrendAnomalyOnly: Bool = false) {
        // Remove only the morning brief (never wipe the weekly report).
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning-brief"])

        let content = UNMutableNotificationContent()
        content.title = "☀️ Morning Brief"
        content.body = "Your health trends are ready. See what matters today."
        content.sound = .default
        content.badge = 1

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "morning-brief",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to schedule: \(error)")
            }
        }
    }

    /// Schedule the Sunday weekly report notification (fires 9:00 AM Sunday).
    /// This is the weekly "ritual" that brings users back and showcases the Pro deep-dive.
    func scheduleWeeklyBrief() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-brief"])

        let content = UNMutableNotificationContent()
        content.title = "📊 Your Weekly Report"
        content.body = "Your week-over-week trends are ready. Tap to see the deep-dive."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly-brief",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Weekly schedule failed: \(error)")
            }
        }
    }

    /// Send an immediate notification for a trend anomaly alert (only when triggered)
    func sendTrendAnomalyAlert(metricName: String, summary: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Trend Change: \(metricName)"
        content.body = summary
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "trend-anomaly-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Immediate
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("[NotificationService] Failed to send anomaly alert: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}
