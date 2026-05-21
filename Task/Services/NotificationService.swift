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

    /// How many upcoming occurrences to schedule for a repeating reminder. iOS caps
    /// total pending notifications at 64 per app, so this is a safe per-task batch.
    /// Subsequent occurrences are re-scheduled the next time the task is saved.
    static let repeatBatchSize = 16

    static func schedule(for task: TaskItem) {
        cancel(for: task)
        guard task.hasReminder, let anchor = task.primaryReminderDate else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: anchor)
        // Tasks only carry a date; the time-of-day comes from the board's Reminder Time setting.
        if components.hour == 0 && components.minute == 0 {
            let minutes = task.board?.reminderMinutesOfDay ?? ReminderDefaults.defaultMinutesOfDay
            components.hour = minutes / 60
            components.minute = minutes % 60
        }
        guard let resolvedAnchor = Calendar.current.date(from: components) else { return }

        let rule = task.repeatRule

        // Build the list of upcoming fire dates. `UNCalendarNotificationTrigger` with
        // `repeats: true` can't express "fire daily *starting* on date X", so we
        // schedule a batch of one-shots instead. When the user saves the task again
        // (manual advance, edit, import), the batch is refreshed.
        let fireDates: [Date]
        if rule == .none {
            fireDates = [resolvedAnchor]
        } else {
            var dates: [Date] = []
            dates.reserveCapacity(Self.repeatBatchSize)
            var cursor = resolvedAnchor
            for _ in 0..<Self.repeatBatchSize {
                dates.append(cursor)
                cursor = rule.advance(cursor)
            }
            fireDates = dates
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

        let center = UNUserNotificationCenter.current()
        for (offset, fire) in fireDates.enumerated() {
            // Skip occurrences already in the past — they'd never deliver.
            if fire <= Date() { continue }
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let identifier = offset == 0 ? task.id.uuidString : "\(task.id.uuidString)@\(offset)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    static func cancel(for task: TaskItem) {
        // Cover both the single-shot identifier and every repeat-batch index so a
        // task that previously had a Daily repeat can be cleanly turned off.
        var identifiers = [task.id.uuidString]
        for i in 1..<Self.repeatBatchSize {
            identifiers.append("\(task.id.uuidString)@\(i)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
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
