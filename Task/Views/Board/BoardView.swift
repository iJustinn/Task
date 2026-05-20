import SwiftUI
import SwiftData

struct BoardView: View {
    let board: Board
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var editingGroup: BoardGroup?
    @State private var editingTask: TaskItem?

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderView(board: board)
            Divider().opacity(0.4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(board.orderedGroups, id: \.id) { group in
                        ColumnView(
                            group: group,
                            width: settings.columnWidth.width,
                            onTapTask: { task in editingTask = task },
                            onMenuTap: { editingGroup = group },
                            onDropTask: { task in moveTask(task, to: group) },
                            onReorder: { task, index in reorder(task, in: group, toIndex: index) },
                            onGroupReorder: { dragged in reorderGroup(dragged, toPositionOf: group) }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .sheet(item: $editingGroup) { group in
            GroupMenuSheet(group: group, board: board)
        }
        .sheet(item: $editingTask) { task in
            TaskDetailView(board: board, mode: .edit(task))
        }
    }

    private func moveTask(_ task: TaskItem, to group: BoardGroup) {
        task.group = group
        task.touch()
        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
    }

    private func reorder(_ task: TaskItem, in group: BoardGroup, toIndex index: Int) {
        var ordered = group.orderedTasks.filter { $0.id != task.id }
        let safeIndex = max(0, min(index, ordered.count))
        ordered.insert(task, at: safeIndex)
        for (i, t) in ordered.enumerated() {
            t.sortIndex = i
        }
        try? context.save()
    }

    private func reorderGroup(_ dragged: BoardGroup, toPositionOf target: BoardGroup) {
        guard dragged.id != target.id else { return }
        var ordered = board.orderedGroups
        guard let from = ordered.firstIndex(where: { $0.id == dragged.id }),
              let to = ordered.firstIndex(where: { $0.id == target.id }) else { return }
        let item = ordered.remove(at: from)
        ordered.insert(item, at: to)
        for (i, g) in ordered.enumerated() {
            g.sortIndex = i
        }
        try? context.save()
    }
}

