import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func schedule(for task: TaskItem) {
        cancel(for: task)
        guard task.hasReminder, let fireDate = task.primaryReminderDate else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        // Tasks only carry a date; the time-of-day comes from the user's Reminder Time setting.
        if components.hour == 0 && components.minute == 0 {
            let minutes = ReminderDefaults.storedMinutesOfDay()
            components.hour = minutes / 60
            components.minute = minutes % 60
        }
        // UNCalendarNotificationTrigger with a past date never fires. Skip rather than
        // schedule a silent no-op so callers don't believe a reminder is set.
        if let resolved = Calendar.current.date(from: components), resolved <= Date() {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = task.title.isEmpty ? String(localized: "Task reminder") : task.title
        if !task.notes.isEmpty {
            content.body = task.notes
        }
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func cancel(for task: TaskItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
}
