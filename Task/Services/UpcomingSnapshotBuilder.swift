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

        let upcoming = allTasks.compactMap { task -> SharedDefaultsService.UpcomingSnapshotEntry? in
            guard let when = task.dueDate ?? task.workingEnd ?? task.workingStart else { return nil }
            guard when >= calendar.startOfDay(for: now), when <= calendar.startOfDay(for: sevenDaysOut).addingTimeInterval(86_400 - 1) else {
                return nil
            }
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
            let l = left.dueDate ?? left.workingEnd ?? left.workingStart ?? .distantFuture
            let r = right.dueDate ?? right.workingEnd ?? right.workingStart ?? .distantFuture
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
