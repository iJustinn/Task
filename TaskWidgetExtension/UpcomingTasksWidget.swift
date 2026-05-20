import WidgetKit
import SwiftUI

struct UpcomingTasksWidget: Widget {
    let kind: String = "UpcomingTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingTasksProvider()) { entry in
            UpcomingTasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Upcoming Tasks")
        .description("See your next tasks with reminders set.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UpcomingTasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UpcomingTasksEntry

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: largeView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            if let first = entry.snapshot.entries.first {
                taskRow(first, compact: true)
            } else {
                Text("No upcoming")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(entry.snapshot.entries.count) upcoming")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            ForEach(entry.snapshot.entries.prefix(3)) { task in
                taskRow(task, compact: false)
            }
            if entry.snapshot.entries.isEmpty {
                Text("No upcoming tasks").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ForEach(entry.snapshot.entries.prefix(7)) { task in
                taskRow(task, compact: false)
            }
            if entry.snapshot.entries.isEmpty {
                Text("No upcoming tasks").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "checklist")
                .foregroundStyle(.tint)
            Text("Upcoming")
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
    }

    @ViewBuilder
    private func taskRow(_ task: WidgetUpcomingEntry, compact: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(task.widgetColor.hue)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(compact ? .caption.weight(.semibold) : .footnote.weight(.semibold))
                    .lineLimit(1)
                if let date = task.primaryDate {
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
