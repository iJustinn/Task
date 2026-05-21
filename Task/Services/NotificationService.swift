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
        // Tasks only carry a date; the time-of-day comes from the board's Reminder Time setting.
        if components.hour == 0 && components.minute == 0 {
            let minutes = task.board?.reminderMinutesOfDay ?? ReminderDefaults.defaultMinutesOfDay
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

        if let board = task.board {
            content.subtitle = boardSubtitle(for: board)
            content.threadIdentifier = board.id.uuidString
        }

        let body = composedBody(for: task)
        if !body.isEmpty {
            content.body = body
        }
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func cancel(for task: TaskItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }

    private static func boardSubtitle(for board: Board) -> String {
        let icon = board.iconEmoji.trimmingCharacters(in: .whitespaces)
        let name = board.title.trimmingCharacters(in: .whitespaces)
        switch (icon.isEmpty, name.isEmpty) {
        case (false, false): return "\(icon) \(name)"
        case (true,  false): return name
        case (false, true):  return icon
        case (true,  true):  return ""
        }
    }

    private static func composedBody(for task: TaskItem) -> String {
        var metaParts: [String] = []
        if let datePhrase = dateSummary(for: task) {
            metaParts.append(datePhrase)
        }
        if let groupName = task.group?.name.trimmingCharacters(in: .whitespaces), !groupName.isEmpty {
            metaParts.append(groupName)
        }
        let tagChips = (task.tags ?? [])
            .map { $0.name.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { "#\($0)" }
        if !tagChips.isEmpty {
            metaParts.append(tagChips.joined(separator: " "))
        }

        let metaLine = metaParts.joined(separator: " · ")
        let notes = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.count > 120 ? String(notes.prefix(119)) + "…" : notes

        switch (metaLine.isEmpty, trimmedNotes.isEmpty) {
        case (false, false): return "\(metaLine)\n\(trimmedNotes)"
        case (false, true):  return metaLine
        case (true,  false): return trimmedNotes
        case (true,  true):  return ""
        }
    }

    private static func dateSummary(for task: TaskItem) -> String? {
        if let due = task.dueDate {
            return String(localized: "Due \(TaskDateFormat.format(due))")
        }
        if let start = task.workingStart {
            return String(localized: "Working \(TaskDateFormat.formatRange(start, task.workingEnd))")
        }
        return nil
    }
}
