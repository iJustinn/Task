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
        guard let boardID = config.board?.id else { return snapshot }
        var filtered = snapshot
        filtered.entries = snapshot.entries.filter { $0.boardID == boardID }
        return filtered
    }
}
