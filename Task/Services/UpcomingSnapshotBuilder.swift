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

        let windowStart = calendar.startOfDay(for: now)
        let windowEnd = calendar.startOfDay(for: sevenDaysOut).addingTimeInterval(86_400 - 1)

        // Include a task if any of its dates — or its working range — intersects the
        // widget window. The previous "earliest date inside window" check excluded
        // ongoing ranges that started before today, hiding active work during the
        // period it most needs to be visible.
        func overlapsWindow(_ task: TaskItem) -> Bool {
            if let start = task.workingStart {
                let end = task.workingEnd ?? start
                let low = min(start, end)
                let high = max(start, end)
                if low <= windowEnd && high >= windowStart { return true }
            }
            if let due = task.dueDate, due >= windowStart, due <= windowEnd {
                return true
            }
            return false
        }

        let upcoming = allTasks.compactMap { task -> SharedDefaultsService.UpcomingSnapshotEntry? in
            guard overlapsWindow(task) else { return nil }
            guard let board = task.board else { return nil }
            return SharedDefaultsService.UpcomingSnapshotEntry(
                id: task.id,
                title: task.title,
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
