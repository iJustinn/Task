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
                groupID: task.group?.id,
                groupName: task.group?.name ?? "",
                groupColorKey: task.group?.colorKey.rawValue ?? ColorKey.gray.rawValue,
                groupSortIndex: task.group?.sortIndex,
                boardID: board.id,
                boardEmoji: board.iconEmoji,
                boardTitle: board.title
            )
        }

        let snapshot = SharedDefaultsService.UpcomingSnapshot(entries: sortedEntries(upcoming), updatedAt: Date())
        SharedDefaultsService.writeUpcoming(snapshot)

        let boardList = allBoards
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { SharedDefaultsService.BoardListEntry(id: $0.id, title: $0.title, iconEmoji: $0.iconEmoji) }
        SharedDefaultsService.writeBoardList(boardList)

        SharedDefaultsService.writeStatusList(statusListEntries(from: allBoards))

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func statusListEntries(from boards: [Board]) -> [SharedDefaultsService.StatusListEntry] {
        boards
            .sorted { $0.sortIndex < $1.sortIndex }
            .flatMap { board in
                board.orderedGroups.map { group in
                    SharedDefaultsService.StatusListEntry(
                        id: group.id,
                        boardID: board.id,
                        boardEmoji: board.iconEmoji,
                        boardTitle: board.title,
                        name: group.name,
                        colorKey: group.colorKey.rawValue,
                        sortIndex: group.sortIndex
                    )
                }
            }
    }

    static func sortedEntries(
        _ entries: [SharedDefaultsService.UpcomingSnapshotEntry]
    ) -> [SharedDefaultsService.UpcomingSnapshotEntry] {
        entries.sorted { left, right in
            let leftGroupOrder = left.groupSortIndex ?? Int.max
            let rightGroupOrder = right.groupSortIndex ?? Int.max
            if leftGroupOrder != rightGroupOrder { return leftGroupOrder < rightGroupOrder }

            let leftDate = primaryWidgetDate(left)
            let rightDate = primaryWidgetDate(right)
            if leftDate != rightDate { return leftDate < rightDate }

            let titleComparison = left.title.localizedCaseInsensitiveCompare(right.title)
            if titleComparison != .orderedSame { return titleComparison == .orderedAscending }

            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func primaryWidgetDate(_ entry: SharedDefaultsService.UpcomingSnapshotEntry) -> Date {
        [entry.workingStart, entry.workingEnd, entry.dueDate].compactMap { $0 }.min() ?? .distantFuture
    }
}
