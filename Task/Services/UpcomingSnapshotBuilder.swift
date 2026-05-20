import Foundation
import SwiftData
import WidgetKit

enum UpcomingSnapshotBuilder {
    @MainActor
    static func writeSnapshot(from context: ModelContext) {
        let descriptor = FetchDescriptor<TaskItem>()
        let all = (try? context.fetch(descriptor)) ?? []

        let calendar = Calendar.current
        let now = Date()
        let sevenDaysOut = calendar.date(byAdding: .day, value: 7, to: now) ?? now

        let upcoming = all.compactMap { task -> SharedDefaultsService.UpcomingSnapshotEntry? in
            guard let when = task.dueDate ?? task.workingEnd ?? task.workingStart else { return nil }
            guard when >= calendar.startOfDay(for: now), when <= calendar.startOfDay(for: sevenDaysOut).addingTimeInterval(86_400 - 1) else {
                return nil
            }
            return SharedDefaultsService.UpcomingSnapshotEntry(
                id: task.id,
                title: task.title.isEmpty ? "Untitled" : task.title,
                dueDate: task.dueDate,
                workingStart: task.workingStart,
                workingEnd: task.workingEnd,
                groupName: task.group?.name ?? "",
                groupColorKey: task.group?.colorKey.rawValue ?? ColorKey.gray.rawValue
            )
        }.sorted { left, right in
            let l = left.dueDate ?? left.workingEnd ?? left.workingStart ?? .distantFuture
            let r = right.dueDate ?? right.workingEnd ?? right.workingStart ?? .distantFuture
            return l < r
        }

        let snapshot = SharedDefaultsService.UpcomingSnapshot(entries: upcoming, updatedAt: Date())
        SharedDefaultsService.writeUpcoming(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
