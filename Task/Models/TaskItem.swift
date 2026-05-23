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
    var showsCheckbox: Bool = false
    var isChecked: Bool = false
    var repeatRuleRaw: String = ""

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

    func matchesDateFilter(_ date: Date, target: AppDateFilterTarget, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)

        switch target {
        case .workingDate:
            guard let workingStart else { return false }
            let startDay = calendar.startOfDay(for: workingStart)
            let endDay = calendar.startOfDay(for: workingEnd ?? workingStart)
            let lowerBound = min(startDay, endDay)
            let upperBound = max(startDay, endDay)
            return day >= lowerBound && day <= upperBound
        case .dueDate:
            guard let dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: day)
        }
    }

    /// When both a working start and a due date exist we don't know which the user
    /// considers "the" deadline — fire (and badge) the earlier one so the reminder
    /// arrives in time for whichever comes first. When only working is set (single
    /// day or range), fire on `workingStart` — the start of the work — so the
    /// reminder arrives when the user needs to begin, not when the window closes.
    var primaryReminderDate: Date? {
        if let w = workingStart, let d = dueDate {
            return min(w, d)
        }
        return dueDate ?? workingStart ?? workingEnd
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRaw) ?? .none }
        set { repeatRuleRaw = newValue.rawValue }
    }

    func touch() {
        updatedAt = Date()
    }

    func duplicated(sortIndex: Int) -> TaskItem {
        let copy = TaskItem(title: title, notes: notes, sortIndex: sortIndex)
        copy.workingStart = workingStart
        copy.workingEnd = workingEnd
        copy.dueDate = dueDate
        copy.hasReminder = hasReminder
        copy.showsCheckbox = showsCheckbox
        copy.isChecked = isChecked
        copy.repeatRule = repeatRule
        copy.board = board
        copy.group = group
        copy.tags = tags
        return copy
    }
}
