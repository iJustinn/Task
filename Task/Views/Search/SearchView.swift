import SwiftUI
import SwiftData

struct SearchView: View {
    let board: Board
    let queryText: String
    var onSelectTask: (TaskItem) -> Void

    var body: some View {
        Group {
            if queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "Search Tasks",
                    systemImage: "magnifyingglass",
                    description: Text("Type to search title, notes, tags, or groups.")
                )
            } else if filteredTasks.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("No tasks match \"\(queryText)\".")
                )
            } else {
                List {
                    ForEach(filteredTasks, id: \.id) { task in
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
                }
                .listStyle(.plain)
            }
        }
    }

    private var filteredTasks: [TaskItem] {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        let all = board.tasks ?? []
        return all.filter { task in
            if task.title.lowercased().contains(query) { return true }
            if task.notes.lowercased().contains(query) { return true }
            if let group = task.group, group.name.lowercased().contains(query) { return true }
            if let tags = task.tags, tags.contains(where: { $0.name.lowercased().contains(query) }) { return true }
            return false
        }
        .sorted { ($0.updatedAt) > ($1.updatedAt) }
    }
}
