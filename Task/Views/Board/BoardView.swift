import SwiftUI
import SwiftData

struct BoardView: View {
    let board: Board
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var editingGroup: BoardGroup?
    @State private var editingTask: TaskItem?
    @State private var draggingTaskID: UUID?
    @State private var dragSessionEnded: Bool = false
    @State private var refreshToken: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderView(board: board)
            Divider().opacity(0.4)
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(board.orderedGroups, id: \.id) { group in
                            ColumnView(
                                group: group,
                                width: settings.columnWidth.width,
                                sortField: board.cardSortField,
                                sortDirection: board.cardSortDirection,
                                draggingTaskID: $draggingTaskID,
                                dragSessionEnded: $dragSessionEnded,
                                refreshToken: refreshToken,
                                onTapTask: { task in editingTask = task },
                                onMenuTap: { editingGroup = group },
                                onPlaceTask: { task, index, commit in placeTask(task, in: group, atIndex: index, commit: commit) },
                                onGroupReorder: { dragged in reorderGroup(dragged, toPositionOf: group) }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 112)
                    .frame(minHeight: geo.size.height, alignment: .topLeading)
                }
                .refreshable {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    refreshToken &+= 1
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .sheet(item: $editingGroup) { group in
            GroupMenuSheet(group: group, board: board)
        }
        .sheet(item: $editingTask) { task in
            TaskDetailView(board: board, mode: .edit(task))
        }
    }

    /// Reassigns the task's group if needed, places it at `index` in the destination
    /// column's manual order, renumbers sortIndex, and (when `commit` is true) saves
    /// + refreshes the widget snapshot. `commit: false` is used during the live drag
    /// to animate without persisting until the user releases. Skips work entirely
    /// when the move would be a no-op so live drag doesn't bounce.
    private func placeTask(_ task: TaskItem, in group: BoardGroup, atIndex index: Int, commit: Bool) {
        let crossColumn = task.group?.id != group.id
        let currentOrdered = group.orderedTasks
        let withoutTask = currentOrdered.filter { $0.id != task.id }
        let safeIndex = max(0, min(index, withoutTask.count))
        if !crossColumn,
           let currentIndex = currentOrdered.firstIndex(where: { $0.id == task.id }),
           currentIndex == safeIndex {
            if commit { try? context.save() }
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            if crossColumn {
                task.group = group
                task.touch()
            }
            var newOrdered = withoutTask
            newOrdered.insert(task, at: safeIndex)
            for (i, t) in newOrdered.enumerated() {
                if t.sortIndex != i {
                    t.sortIndex = i
                }
            }
        }
        if commit {
            try? context.save()
            UpcomingSnapshotBuilder.writeSnapshot(from: context)
        }
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
