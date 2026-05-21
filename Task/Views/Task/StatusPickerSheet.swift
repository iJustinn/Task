import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct StatusPickerSheet: View {
    let board: Board
    @Binding var selection: BoardGroup?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showAddGroup = false
    @State private var newGroupName: String = ""
    @State private var newGroupColor: ColorKey = .purple
    @State private var draggingGroupID: UUID?
    @State private var dragSessionEnded: Bool = false
    @State private var pendingDelete: BoardGroup?
    @State private var deleteZoneHovered: Bool = false
    @State private var dragOverScreen: Bool = false
    @State private var showDeleteZone: Bool = false
    @State private var hideDeleteZoneTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var canDelete: Bool { board.orderedGroups.count > 1 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(board.orderedGroups, id: \.id) { group in
                            groupTile(group)
                        }

                        Button {
                            showAddGroup = true
                        } label: {
                            GridTile(
                                title: "New",
                                subtitle: "Create status",
                                systemImage: "plus",
                                tintColor: .accentColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 120)
                }

                if showDeleteZone && canDelete {
                    deleteDropZone
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onDrop(of: StringMoveDropDelegate.acceptedTypes, isTargeted: $dragOverScreen) { _ in
                draggingGroupID = nil
                deleteZoneHovered = false
                return false
            }
            .onChange(of: dragOverScreen) { _, isOver in
                hideDeleteZoneTask?.cancel()
                if isOver {
                    showDeleteZone = true
                } else {
                    hideDeleteZoneTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if Task.isCancelled { return }
                        showDeleteZone = false
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: showDeleteZone)
            .navigationTitle("Choose Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $pendingDelete) { group in
                ConfirmationSheet(
                    icon: "trash.fill",
                    iconTint: .red,
                    title: "Delete Status?",
                    message: "“\(group.name)” will be removed. Its tasks will move to the first remaining status.",
                    confirmLabel: "Delete Status"
                ) {
                    deleteGroup(group)
                }
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAddGroup) {
            newGroupSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func groupTile(_ group: BoardGroup) -> some View {
        GridTile(
            title: group.name,
            subtitle: "\(group.orderedTasks.count) tasks",
            dotColor: group.colorKey.dot,
            tintColor: group.colorKey.foreground,
            isSelected: selection?.id == group.id
        )
        .contentShape(Rectangle())
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            selection = group
            dismiss()
        }
        .draggable(beginDragGroup(group)) {
            GridTile(
                title: group.name,
                subtitle: "\(group.orderedTasks.count) tasks",
                dotColor: group.colorKey.dot,
                tintColor: group.colorKey.foreground
            )
            .frame(width: 120)
        }
        .onDrop(
            of: StringMoveDropDelegate.acceptedTypes,
            delegate: StatusPickerReorderDropDelegate(
                target: group,
                board: board,
                context: context,
                draggingGroupID: $draggingGroupID,
                dragSessionEnded: $dragSessionEnded
            )
        )
    }

    private var deleteDropZone: some View {
        let baseColor = Color.red
        let tint = deleteZoneHovered ? baseColor.opacity(0.85) : baseColor.opacity(0.45)
        return HStack(spacing: 10) {
            Image(systemName: "trash.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(deleteZoneHovered ? "Release to delete" : "Drag here to delete")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(baseColor.opacity(deleteZoneHovered ? 0.95 : 0.6), lineWidth: 1.6)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .onDrop(
            of: StringMoveDropDelegate.acceptedTypes,
            delegate: GroupDeleteDropDelegate(
                draggingGroupID: $draggingGroupID,
                dragSessionEnded: $dragSessionEnded,
                hovered: $deleteZoneHovered,
                resolveGroup: { id in board.orderedGroups.first(where: { $0.id == id }) },
                onDelete: { group in pendingDelete = group }
            )
        )
    }

    private func beginDragGroup(_ group: BoardGroup) -> String {
        let groupID = group.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingGroupID = groupID
        }
        return group.id.uuidString
    }

    private var newGroupSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    SettingsCardSection("New Status") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                SettingsIconTile(systemName: "circle.fill", color: newGroupColor.foreground)
                                TextField("Status name", text: $newGroupName)
                                    .font(.system(.headline, design: .rounded))
                            }
                            ColorSwatchPicker(selection: $newGroupColor).padding(.leading, 58)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            }
            .navigationTitle("New Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showAddGroup = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addGroup() }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let existing = board.orderedGroups.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            selection = existing
            newGroupName = ""
            showAddGroup = false
            return
        }
        let sortIndex = (board.orderedGroups.last?.sortIndex ?? -1) + 1
        let group = BoardGroup(name: trimmed, colorKey: newGroupColor, sortIndex: sortIndex)
        group.board = board
        context.insert(group)
        try? context.save()
        selection = group
        newGroupName = ""
        showAddGroup = false
    }

    private func deleteGroup(_ group: BoardGroup) {
        let groups = board.orderedGroups
        guard groups.count > 1 else { return }
        let remaining = groups.filter { $0.id != group.id }
        if let fallback = remaining.first, let tasks = group.tasks {
            // Snapshot the fallback's tail once — see GroupMenuSheet for why reading
            // `fallback.orderedTasks.last` inside the loop produces duplicates.
            var base = (fallback.orderedTasks.last?.sortIndex ?? -1)
            for task in tasks {
                task.group = fallback
                base += 1
                task.sortIndex = base
            }
        }
        if board.defaultGroupUUID == group.id {
            board.defaultGroupUUID = remaining.first?.id
        }
        if selection?.id == group.id {
            selection = remaining.first
        }
        context.delete(group)
        for (idx, g) in remaining.enumerated() { g.sortIndex = idx }
        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
    }
}

private struct StatusPickerReorderDropDelegate: DropDelegate {
    let target: BoardGroup
    let board: Board
    let context: ModelContext
    @Binding var draggingGroupID: UUID?
    @Binding var dragSessionEnded: Bool

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let id = draggingGroupID, id != target.id else { return }
        applyMove(draggedID: id)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let id = draggingGroupID {
            applyMove(draggedID: id)
            try? context.save()
        }
        draggingGroupID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        return true
    }

    private func applyMove(draggedID: UUID) {
        guard draggedID != target.id else { return }
        var ordered = board.orderedGroups
        guard let from = ordered.firstIndex(where: { $0.id == draggedID }),
              let to = ordered.firstIndex(where: { $0.id == target.id }),
              from != to else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            let item = ordered.remove(at: from)
            ordered.insert(item, at: to)
            for (i, g) in ordered.enumerated() { g.sortIndex = i }
        }
    }
}

private struct GroupDeleteDropDelegate: DropDelegate {
    @Binding var draggingGroupID: UUID?
    @Binding var dragSessionEnded: Bool
    @Binding var hovered: Bool
    let resolveGroup: (UUID) -> BoardGroup?
    let onDelete: (BoardGroup) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard !hovered else { return }
        hovered = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func dropExited(info: DropInfo) {
        hovered = false
    }

    func performDrop(info: DropInfo) -> Bool {
        let draggedID = draggingGroupID
        hovered = false
        draggingGroupID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        if let id = draggedID, let group = resolveGroup(id) {
            DispatchQueue.main.async {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                onDelete(group)
            }
            return true
        }
        return false
    }
}
