import SwiftUI
import SwiftData

struct ColumnView: View {
    let group: BoardGroup
    var width: CGFloat = 220
    var onTapTask: (TaskItem) -> Void
    var onMenuTap: () -> Void
    var onDropTask: (TaskItem) -> Void
    var onReorder: (TaskItem, Int) -> Void
    var onGroupReorder: (BoardGroup) -> Void

    @EnvironmentObject private var settings: SettingsViewModel
    @State private var visibleCount: Int = 10

    private let groupDragPrefix = "group:"
    private let pageSize: Int = 10

    private var currentTasks: [TaskItem] {
        group.sortedTasks(field: settings.cardSortField, direction: settings.cardSortDirection)
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

            ScrollView {
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
                            .draggable(task.id.uuidString) {
                                TaskCardView(task: task)
                                    .frame(width: 240)
                            }
                            .onDrop(of: StringMoveDropDelegate.acceptedTypes, delegate: StringMoveDropDelegate { raw in
                                handleDrop(raw: raw, fallbackIndex: index)
                            })
                    }
                    if ordered.count > visibleCount {
                        moreButton(hidden: ordered.count - visibleCount)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .id("\(settings.cardSortField.rawValue)-\(settings.cardSortDirection.rawValue)")
            }
            .scrollIndicators(.hidden)
            .refreshable {
                try? await Task.sleep(nanoseconds: 200_000_000)
                visibleCount = 10
            }
        }
        .frame(width: width, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(group.colorKey.background.opacity(0.45))
        )
        .onDrop(of: StringMoveDropDelegate.acceptedTypes, delegate: StringMoveDropDelegate { raw in
            handleDrop(raw: raw, fallbackIndex: currentTasks.count)
        })
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

    private func handleDrop(raw: String, fallbackIndex: Int) -> Bool {
        if raw.hasPrefix(groupDragPrefix) {
            let trimmed = String(raw.dropFirst(groupDragPrefix.count))
            guard let droppedID = UUID(uuidString: trimmed),
                  let dropped = findGroup(droppedID),
                  dropped.id != group.id else { return false }
            onGroupReorder(dropped)
            return true
        }
        guard let droppedID = UUID(uuidString: raw),
              let dropped = findTask(droppedID) else { return false }
        if dropped.group?.id != group.id {
            onDropTask(dropped)
        }
        onReorder(dropped, fallbackIndex)
        return true
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
