import WidgetKit
import Foundation

struct UpcomingTasksEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetUpcomingSnapshot
}

struct UpcomingTasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingTasksEntry {
        UpcomingTasksEntry(date: Date(), snapshot: WidgetUpcomingSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingTasksEntry) -> Void) {
        let snapshot = WidgetSharedDefaults.read()
        completion(UpcomingTasksEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingTasksEntry>) -> Void) {
        let snapshot = WidgetSharedDefaults.read()
        let now = Date()
        let entry = UpcomingTasksEntry(date: now, snapshot: snapshot)
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
