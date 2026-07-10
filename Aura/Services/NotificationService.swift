import UserNotifications
import Foundation

extension Notification.Name {
    static let openDashboardTab = Notification.Name("openDashboardTab")
    static let openMoodLogger = Notification.Name("openMoodLogger")
}

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "aura_reminder_"

    private override init() {
        super.init()
    }

    // MARK: - Delegate (notification tap / foreground presentation)

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier.hasPrefix(idPrefix) {
            NotificationCenter.default.post(name: .openDashboardTab, object: nil)
        }
        completionHandler()
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Schedule

    /// Full reschedule for the next 60 days — call on enable or time change.
    func scheduleAll(hour: Int, minute: Int, hasLoggedToday: Bool) async {
        await cancelAll()
        let calendar = Calendar.current
        let now = Date()
        var scheduled = 0
        var dayOffset = 0

        while scheduled < 60 {
            guard let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { break }
            dayOffset += 1

            var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            if calendar.isDateInToday(fireDate) && hasLoggedToday { continue }

            let content = UNMutableNotificationContent()
            content.title = "How are you feeling today?"
            content.body = "Tap to log your mood."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(idPrefix)\(scheduled)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
            scheduled += 1
        }
    }

    /// Cancel today's pending notification — call after logging today's mood.
    func cancelToday() async {
        let pending = await center.pendingNotificationRequests()
        let calendar = Calendar.current
        let ids = pending.filter { req in
            guard let trigger = req.trigger as? UNCalendarNotificationTrigger,
                  let fireDate = trigger.nextTriggerDate() else { return false }
            return calendar.isDateInToday(fireDate)
        }.map(\.identifier)
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Re-add today's notification — call after deleting today's mood entry.
    func rescheduleToday(hour: Int, minute: Int) async {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let fireDate = calendar.date(from: components), fireDate > Date() else { return }
        _ = fireDate

        let content = UNMutableNotificationContent()
        content.title = "How are you feeling today?"
        content.body = "Tap to log your mood."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(idPrefix)today",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.filter { $0.identifier.hasPrefix(idPrefix) }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
