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

        let content = UNMutableNotificationContent()
        content.title = task.title.isEmpty ? String(localized: "Task reminder") : task.title
        if !task.notes.isEmpty {
            content.body = task.notes
        }
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        // Default to 9:00 AM if no specific time was set on the date.
        if components.hour == 0 && components.minute == 0 {
            components.hour = 9
            components.minute = 0
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func cancel(for task: TaskItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
}
