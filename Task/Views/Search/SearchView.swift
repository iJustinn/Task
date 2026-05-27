import SwiftUI
import SwiftData

struct SearchView: View {
    let boards: [Board]
    let activeBoardID: UUID?
    let queryText: String
    var onSelectTask: (TaskItem) -> Void

    var body: some View {
        // Compute once per render — `groupedResults` filters and sorts across every
        // board, so evaluating it twice (empty check + ForEach) shows up as typing
        // lag in the search bar at any reasonable task count.
        let results = groupedResults
        return Group {
            if queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "Search Tasks",
                    systemImage: "magnifyingglass",
                    description: Text("Type to search title, notes, tags, or groups across all boards.")
                )
            } else if results.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("No tasks match \"\(queryText)\".")
                )
            } else {
                List {
                    ForEach(results, id: \.board.id) { entry in
                        Section {
                            ForEach(entry.tasks, id: \.id) { task in
                                taskRow(task)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Text(entry.board.iconEmoji)
                                Text(entry.board.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func taskRow(_ task: TaskItem) -> some View {
        Button {
            onSelectTask(task)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title.isEmpty ? String(localized: "Untitled") : task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if hasMetadataRow(for: task) {
                    HStack(alignment: .top, spacing: 8) {
                        searchMetadataChips(for: task)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TaskCardFooterIcons(task: task, showsDivider: false)
                            .padding(.top, 2)
                    }
                }

                searchDateRows(for: task)
            }
        }
        .buttonStyle(.plain)
    }

    private func hasMetadataRow(for task: TaskItem) -> Bool {
        task.group != nil
        || !(task.tags?.isEmpty ?? true)
        || task.repeatRule != .none
        || task.hasNotes
        || task.hasReminder
    }

    @ViewBuilder
    private func searchMetadataChips(for task: TaskItem) -> some View {
        FlowLayout(spacing: 4, lineSpacing: 4) {
            if let group = task.group {
                TagChip(name: group.name, colorKey: group.colorKey, compact: true)
            }
            if task.group != nil, !(task.tags?.isEmpty ?? true) {
                SearchMetadataSeparatorDot()
            }
            if let tags = task.tags {
                ForEach(tags, id: \.id) { tag in
                    TagChip(name: tag.name, colorKey: tag.colorKey, compact: true)
                }
            }
        }
    }

    @ViewBuilder
    private func searchDateRows(for task: TaskItem) -> some View {
        if task.workingStart != nil || task.dueDate != nil {
            VStack(alignment: .leading, spacing: 2) {
                if let start = task.workingStart {
                    let today = Calendar.current.startOfDay(for: Date())
                    let upcoming = Calendar.current.startOfDay(for: start) > today
                    DateRow(
                        start: start,
                        end: task.workingEnd,
                        tint: upcoming ? ColorKey.blue.foreground : ColorKey.red.foreground
                    )
                }
                if let due = task.dueDate {
                    let today = Calendar.current.startOfDay(for: Date())
                    let upcoming = Calendar.current.startOfDay(for: due) > today
                    DueDateRow(date: due, isUpcoming: upcoming)
                }
            }
        }
    }

    private struct ResultGroup {
        let board: Board
        let tasks: [TaskItem]
    }

    private var groupedResults: [ResultGroup] {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return orderedBoards.compactMap { board in
            let matches = (board.tasks ?? []).filter { $0.matchesSearchQuery(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
            return matches.isEmpty ? nil : ResultGroup(board: board, tasks: matches)
        }
    }

    /// Active board first so the user's current context surfaces at the top;
    /// remaining boards follow their normal sidebar order.
    private var orderedBoards: [Board] {
        let rest = boards
            .filter { $0.id != activeBoardID }
            .sorted { $0.sortIndex < $1.sortIndex }
        if let activeID = activeBoardID,
           let active = boards.first(where: { $0.id == activeID }) {
            return [active] + rest
        }
        return rest
    }
}

private struct SearchMetadataSeparatorDot: View {
    @ScaledMetric(relativeTo: .caption2) private var diameter: CGFloat = 3

    var body: some View {
        Text(verbatim: "M")
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(.clear)
            .padding(.vertical, 2)
            .frame(width: diameter + 4)
            .overlay(alignment: .center) {
                Circle()
                    .fill(Color.secondary.opacity(0.65))
                    .frame(width: diameter, height: diameter)
            }
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityHidden(true)
    }
}
