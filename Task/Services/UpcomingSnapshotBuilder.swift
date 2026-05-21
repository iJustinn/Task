import Foundation
import SwiftData
import WidgetKit

enum UpcomingSnapshotBuilder {
    @MainActor
    static func writeSnapshot(from context: ModelContext) {
        let allTasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let allBoards = (try? context.fetch(FetchDescriptor<Board>())) ?? []

        let calendar = Calendar.current
        let now = Date()
        let sevenDaysOut = calendar.date(byAdding: .day, value: 7, to: now) ?? now

        // Use the earliest set date so a task that "starts tomorrow" but is "due next
        // month" still surfaces in the 7-day widget window — the old `dueDate ??
        // workingEnd ?? workingStart` would have hidden it behind the later due date.
        func earliestDate(_ task: TaskItem) -> Date? {
            let candidates = [task.workingStart, task.workingEnd, task.dueDate].compactMap { $0 }
            return candidates.min()
        }
        let windowStart = calendar.startOfDay(for: now)
        let windowEnd = calendar.startOfDay(for: sevenDaysOut).addingTimeInterval(86_400 - 1)

        let upcoming = allTasks.compactMap { task -> SharedDefaultsService.UpcomingSnapshotEntry? in
            guard let when = earliestDate(task) else { return nil }
            guard when >= windowStart, when <= windowEnd else { return nil }
            guard let board = task.board else { return nil }
            return SharedDefaultsService.UpcomingSnapshotEntry(
                id: task.id,
                title: task.title.isEmpty ? "Untitled" : task.title,
                dueDate: task.dueDate,
                workingStart: task.workingStart,
                workingEnd: task.workingEnd,
                groupName: task.group?.name ?? "",
                groupColorKey: task.group?.colorKey.rawValue ?? ColorKey.gray.rawValue,
                boardID: board.id,
                boardEmoji: board.iconEmoji,
                boardTitle: board.title
            )
        }.sorted { left, right in
            let l = [left.workingStart, left.workingEnd, left.dueDate].compactMap { $0 }.min() ?? .distantFuture
            let r = [right.workingStart, right.workingEnd, right.dueDate].compactMap { $0 }.min() ?? .distantFuture
            return l < r
        }

        let snapshot = SharedDefaultsService.UpcomingSnapshot(entries: upcoming, updatedAt: Date())
        SharedDefaultsService.writeUpcoming(snapshot)

        let boardList = allBoards
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { SharedDefaultsService.BoardListEntry(id: $0.id, title: $0.title, iconEmoji: $0.iconEmoji) }
        SharedDefaultsService.writeBoardList(boardList)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
