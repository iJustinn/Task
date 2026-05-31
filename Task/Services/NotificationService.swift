import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Previous versions scheduled repeat reminders as a fixed batch of one-shots.
    /// Keep cancelling those legacy identifiers so upgrading users don't keep
    /// receiving future repeat notifications for a date they have not moved.
    static let legacyRepeatBatchSize = 16

    static func schedule(for task: TaskItem) {
        cancel(for: task)
        let fireDates = Self.fireDates(for: task)
        guard !fireDates.isEmpty else { return }

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

        let center = UNUserNotificationCenter.current()
        for fire in fireDates {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let identifier = task.id.uuidString
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    static func fireDates(for task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        guard let resolvedAnchor = resolvedFireDate(for: task, calendar: calendar), resolvedAnchor > now else { return [] }

        // Repeat controls date advancement on the task card, not notification recurrence.
        return [resolvedAnchor]
    }

    static func cancel(for task: TaskItem) {
        // Cover both the current single-shot identifier and legacy repeat-batch
        // identifiers so old Daily/Weekly reminders can be cleanly turned off.
        var identifiers = [task.id.uuidString]
        for i in 1..<Self.legacyRepeatBatchSize {
            identifiers.append("\(task.id.uuidString)@\(i)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func resolvedFireDate(for task: TaskItem, calendar: Calendar) -> Date? {
        guard task.hasReminder else { return nil }

        // Resolve each candidate to its real fire time BEFORE comparing. A date at
        // midnight carries no specific time and takes the board's Reminder Time, so its
        // resolved time can be later than another date's explicit time. Comparing the
        // raw (pre-fallback) dates would wrongly pick the midnight one as "earliest"
        // (e.g. working 08:00 + due with no time + board 09:00 must fire at 08:00).
        // When neither working start nor due exists, fall back to working end.
        let resolved = [task.workingStart, task.dueDate]
            .compactMap { resolvedTimeOfDay(for: $0, board: task.board, calendar: calendar) }
        if let earliest = resolved.min() { return earliest }
        return resolvedTimeOfDay(for: task.workingEnd, board: task.board, calendar: calendar)
    }

    /// A task date carries only a day unless the user set a Specific Time. A midnight
    /// value means "no specific time" and takes the board's Reminder Time; any other
    /// time-of-day is used as-is.
    private static func resolvedTimeOfDay(for date: Date?, board: Board?, calendar: Calendar) -> Date? {
        guard let date else { return nil }
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        if components.hour == 0 && components.minute == 0 {
            let minutes = board?.reminderMinutesOfDay ?? ReminderDefaults.defaultMinutesOfDay
            components.hour = minutes / 60
            components.minute = minutes % 60
        }
        return calendar.date(from: components)
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
        let style = TaskDateFormat.currentStyle
        if let due = task.dueDate {
            return String(localized: "Due \(TaskDateFormat.format(due, style: style))")
        }
        if let start = task.workingStart {
            return String(localized: "Working \(TaskDateFormat.formatRange(start, task.workingEnd, style: style))")
        }
        return nil
    }
}
