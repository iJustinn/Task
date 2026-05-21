import SwiftUI
import SwiftData

struct SearchView: View {
    let boards: [Board]
    let activeBoardID: UUID?
    let queryText: String
    var onSelectTask: (TaskItem) -> Void

    var body: some View {
        Group {
            if queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "Search Tasks",
                    systemImage: "magnifyingglass",
                    description: Text("Type to search title, notes, tags, or groups across all boards.")
                )
            } else if groupedResults.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("No tasks match \"\(queryText)\".")
                )
            } else {
                List {
                    ForEach(groupedResults, id: \.board.id) { entry in
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
                HStack {
                    if task.hasNotes {
                        Image(systemName: "doc.text")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(task.title.isEmpty ? "Untitled" : task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                HStack(spacing: 4) {
                    if let group = task.group {
                        Circle().fill(group.colorKey.dot).frame(width: 7, height: 7)
                        Text(group.name)
                            .font(.caption)
                            .foregroundStyle(group.colorKey.foreground)
                    }
                    Spacer()
                    if let due = task.dueDate {
                        Text(TaskDateFormat.format(due))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private struct ResultGroup {
        let board: Board
        let tasks: [TaskItem]
    }

    private var groupedResults: [ResultGroup] {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return orderedBoards.compactMap { board in
            let matches = (board.tasks ?? []).filter { task in
                if task.title.lowercased().contains(query) { return true }
                if task.notes.lowercased().contains(query) { return true }
                if let group = task.group, group.name.lowercased().contains(query) { return true }
                if let tags = task.tags, tags.contains(where: { $0.name.lowercased().contains(query) }) { return true }
                return false
            }
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
