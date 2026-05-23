import WidgetKit
import Foundation
import AppIntents

struct UpcomingTasksEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetUpcomingSnapshot
    let configuration: BoardConfigurationIntent
}

struct UpcomingTasksProvider: AppIntentTimelineProvider {
    typealias Entry = UpcomingTasksEntry
    typealias Intent = BoardConfigurationIntent

    func placeholder(in context: Context) -> UpcomingTasksEntry {
        UpcomingTasksEntry(date: Date(), snapshot: WidgetUpcomingSnapshot(), configuration: BoardConfigurationIntent())
    }

    func snapshot(for configuration: BoardConfigurationIntent, in context: Context) async -> UpcomingTasksEntry {
        let raw = WidgetSharedDefaults.read()
        let filtered = filter(raw, by: configuration)
        return UpcomingTasksEntry(date: Date(), snapshot: filtered, configuration: configuration)
    }

    func timeline(for configuration: BoardConfigurationIntent, in context: Context) async -> Timeline<UpcomingTasksEntry> {
        let raw = WidgetSharedDefaults.read()
        let filtered = filter(raw, by: configuration)
        let now = Date()
        let entry = UpcomingTasksEntry(date: now, snapshot: filtered, configuration: configuration)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func filter(_ snapshot: WidgetUpcomingSnapshot, by config: BoardConfigurationIntent) -> WidgetUpcomingSnapshot {
        let boardID = config.board?.id
        // If the user picked a status from a different board than the
        // configured board, the AND of the two filters can never match.
        // Drop the status filter in that case so the widget surfaces the
        // board's tasks instead of locking into a permanent "No upcoming".
        let effectiveStatus: StatusEntity? = {
            guard let status = config.status else { return nil }
            if let boardID, status.boardID != boardID { return nil }
            return status
        }()
        let statusID = effectiveStatus?.id
        guard boardID != nil || statusID != nil else { return snapshot }

        var filtered = snapshot
        filtered.entries = snapshot.entries.filter { entry in
            if let boardID, entry.boardID != boardID { return false }
            if let statusID, entry.groupID != statusID { return false }
            return true
        }
        return filtered
    }
}
