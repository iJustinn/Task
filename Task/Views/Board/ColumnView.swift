import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ColumnView: View {
    let group: BoardGroup
    var width: CGFloat = 220
    @Binding var draggingTaskID: UUID?
    @Binding var dragSessionEnded: Bool
    var refreshToken: Int = 0
    var onTapTask: (TaskItem) -> Void
    var onMenuTap: () -> Void
    var onPlaceTask: (TaskItem, Int, Bool) -> Void
    var onGroupReorder: (BoardGroup) -> Void

    @EnvironmentObject private var settings: SettingsViewModel
    @State private var visibleCount: Int = 10

    private let groupDragPrefix = "group:"
    private let pageSize: Int = 10

    private var currentTasks: [TaskItem] {
        group.sortedTasks(field: settings.cardSortField, direction: settings.cardSortDirection)
    }

    private func beginDragTask(_ task: TaskItem) -> String {
        let taskID = task.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingTaskID = taskID
        }
        return task.id.uuidString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupHeaderPill(
                name: group.name,
                count: currentTasks.count,
                colorKey: group.colorKey,
                onMenuTap: onMenuTap
            )
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .contentShape(Rectangle())
            .contentShape(.dragPreview, Capsule(style: .continuous))
            .draggable("\(groupDragPrefix)\(group.id.uuidString)") {
                GroupHeaderPill(
                    name: group.name,
                    count: currentTasks.count,
                    colorKey: group.colorKey
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }

            LazyVStack(spacing: 8) {
                let ordered = currentTasks
                let visible = Array(ordered.prefix(visibleCount))
                let sortKey = "\(settings.cardSortField.rawValue)-\(settings.cardSortDirection.rawValue)"
                let _ = sortKey // forces dependency for re-render
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, task in
                    TaskCardView(task: task)
                        .contentShape(Rectangle())
                        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .onTapGesture { onTapTask(task) }
                        .draggable(beginDragTask(task)) {
                            TaskCardView(task: task)
                                .frame(width: 240)
                        }
                        .onDrop(
                            of: StringMoveDropDelegate.acceptedTypes,
                            delegate: TaskRowDropDelegate(
                                targetTask: task,
                                targetGroup: group,
                                sortField: settings.cardSortField,
                                onPlaceTask: onPlaceTask,
                                onGroupReorder: onGroupReorder,
                                findTask: findTask,
                                findGroup: findGroup,
                                draggingTaskID: $draggingTaskID,
                                dragSessionEnded: $dragSessionEnded
                            )
                        )
                }
                if ordered.count > visibleCount {
                    moreButton(hidden: ordered.count - visibleCount)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
            .id("\(settings.cardSortField.rawValue)-\(settings.cardSortDirection.rawValue)")
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(group.colorKey.background.opacity(0.45))
        )
        .onDrop(
            of: StringMoveDropDelegate.acceptedTypes,
            delegate: TaskRowDropDelegate(
                targetTask: nil,
                targetGroup: group,
                sortField: settings.cardSortField,
                onPlaceTask: onPlaceTask,
                onGroupReorder: onGroupReorder,
                findTask: findTask,
                findGroup: findGroup,
                draggingTaskID: $draggingTaskID,
                dragSessionEnded: $dragSessionEnded
            )
        )
        .onChange(of: refreshToken) { _, _ in
            visibleCount = pageSize
        }
    }

    private func moreButton(hidden: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                visibleCount += pageSize
            }
        } label: {
            HStack(spacing: 6) {
                Text("More")
                    .font(.subheadline.weight(.semibold))
                Text("+\(min(pageSize, hidden))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(group.colorKey.foreground.opacity(0.7))
            }
            .foregroundStyle(group.colorKey.foreground)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(group.colorKey.background.opacity(0.7))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func findTask(_ id: UUID) -> TaskItem? {
        guard let board = group.board else { return nil }
        let tasks: [TaskItem] = board.tasks ?? []
        return tasks.first(where: { $0.id == id })
    }

    private func findGroup(_ id: UUID) -> BoardGroup? {
        guard let board = group.board else { return nil }
        return board.orderedGroups.first(where: { $0.id == id })
    }
}

private struct TaskRowDropDelegate: DropDelegate {
    let targetTask: TaskItem?
    let targetGroup: BoardGroup
    let sortField: CardSortField
    let onPlaceTask: (TaskItem, Int, Bool) -> Void
    let onGroupReorder: (BoardGroup) -> Void
    let findTask: (UUID) -> TaskItem?
    let findGroup: (UUID) -> BoardGroup?
    @Binding var draggingTaskID: UUID?
    @Binding var dragSessionEnded: Bool

    private func currentTargetIndex() -> Int {
        let ordered = targetGroup.orderedTasks
        if let target = targetTask {
            return ordered.firstIndex(where: { $0.id == target.id }) ?? ordered.count
        }
        return ordered.count
    }

    private func currentTaskIndex(_ task: TaskItem) -> Int {
        targetGroup.orderedTasks.firstIndex(where: { $0.id == task.id }) ?? targetGroup.orderedTasks.count
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let id = draggingTaskID, let task = findTask(id) else { return }
        // The column-outer delegate (targetTask == nil) covers the area around
        // the rows including the gap above the first row. If the dragged task
        // is already in this column, firing "move to end" here fights with the
        // first row's "move to index 0", producing visible bouncing. Skip.
        if targetTask == nil && task.group?.id == targetGroup.id {
            return
        }
        applyTaskMove(task, atIndex: currentTargetIndex(), commit: false)
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: StringMoveDropDelegate.acceptedTypes)
        guard let provider = providers.first else {
            cleanup()
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            let resolved: String? = {
                if let s = item as? String { return s }
                if let data = item as? Data, let s = String(data: data, encoding: .utf8) { return s }
                return nil
            }()
            DispatchQueue.main.async {
                defer { cleanup() }
                guard let raw = resolved else { return }
                if raw.hasPrefix("group:") {
                    let stripped = String(raw.dropFirst("group:".count))
                    if let gid = UUID(uuidString: stripped),
                       let g = findGroup(gid),
                       g.id != targetGroup.id {
                        onGroupReorder(g)
                    }
                } else if let tid = UUID(uuidString: raw), let task = findTask(tid) {
                    let placementIndex: Int
                    if targetTask == nil && task.group?.id == targetGroup.id {
                        // Released in the column-outer area for a task already
                        // in this column — keep it where the live drag left it
                        // instead of forcing it to the end.
                        placementIndex = currentTaskIndex(task)
                    } else {
                        placementIndex = currentTargetIndex()
                    }
                    applyTaskMove(task, atIndex: placementIndex, commit: true)
                }
            }
        }
        return true
    }

    private func applyTaskMove(_ task: TaskItem, atIndex index: Int, commit: Bool) {
        let crossColumn = task.group?.id != targetGroup.id
        if sortField == .manual {
            onPlaceTask(task, index, commit)
        } else if crossColumn {
            onPlaceTask(task, Int.max, commit)
        } else if commit {
            // Same column, non-manual sort: persist any earlier cross-column
            // live moves without disturbing the sort-driven order.
            onPlaceTask(task, currentTaskIndex(task), true)
        }
    }

    private func cleanup() {
        draggingTaskID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
    }
}
