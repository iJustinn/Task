import WidgetKit
import SwiftUI
import AppIntents

struct UpcomingTasksWidget: Widget {
    let kind: String = "UpcomingTasksWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: BoardConfigurationIntent.self, provider: UpcomingTasksProvider()) { entry in
            UpcomingTasksWidgetView(entry: entry)
                .widgetBackground(entry.configuration.background ?? .systemDefault)
        }
        .configurationDisplayName("Upcoming Tasks")
        .description("See tasks with a working or due date in the next seven days. Choose a board or show all of them.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct UpcomingTasksWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UpcomingTasksEntry

    private var showBoardBadge: Bool {
        entry.configuration.board == nil
    }

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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(entry.snapshot.entries.count) upcoming")
                .font(.caption)
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
                Text("No upcoming tasks").font(.subheadline).foregroundStyle(.secondary)
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
                Text("No upcoming tasks").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
            Spacer()
        }
    }

    private var headerTitle: String {
        if let board = entry.configuration.board {
            let resolvedTitle = board.title.isEmpty ? String(localized: "Untitled") : board.title
            return "\(board.iconEmoji) \(resolvedTitle)"
        }
        return String(localized: "Upcoming")
    }

    @ViewBuilder
    private func taskRow(_ task: WidgetUpcomingEntry, compact: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(task.widgetColor.hue)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if showBoardBadge, let emoji = task.boardEmoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(compact ? .footnote : .subheadline)
                    }
                    Text(task.title.isEmpty ? String(localized: "Untitled") : task.title)
                        .font(compact ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                if let date = task.primaryDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private extension View {
    @ViewBuilder
    func widgetBackground(_ style: WidgetBackgroundStyle) -> some View {
        switch style {
        case .systemDefault:
            containerBackground(.fill.tertiary, for: .widget)
        case .pureBlack:
            containerBackground(Color.black, for: .widget)
                .environment(\.colorScheme, .dark)
        case .pureWhite:
            containerBackground(Color.white, for: .widget)
                .environment(\.colorScheme, .light)
        }
    }
}
