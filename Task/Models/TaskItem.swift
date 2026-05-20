import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""

    var workingStart: Date?
    var workingEnd: Date?
    var dueDate: Date?

    var hasReminder: Bool = false

    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var board: Board?
    var group: BoardGroup?
    var tags: [TaskTag]? = []

    init(title: String = "", notes: String = "", sortIndex: Int = 0) {
        self.title = title
        self.notes = notes
        self.sortIndex = sortIndex
    }

    var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var workingRange: ClosedRange<Date>? {
        guard let start = workingStart else { return nil }
        let end = workingEnd ?? start
        return start...max(end, start)
    }

    var workingIsRange: Bool {
        guard let start = workingStart, let end = workingEnd else { return false }
        return Calendar.current.startOfDay(for: start) != Calendar.current.startOfDay(for: end)
    }

    var primaryReminderDate: Date? {
        dueDate ?? workingEnd ?? workingStart
    }

    func touch() {
        updatedAt = Date()
    }
}
