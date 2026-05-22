import SwiftUI
import SwiftData

struct StatusPickerSheet: View {
    let board: Board
    @Binding var selection: BoardGroup?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var showAddGroup = false
    @State private var newGroupName: String = ""
    @State private var newGroupColor: ColorKey = .purple
    @State private var draggingGroupID: UUID?
    @State private var dragSessionEnded: Bool = false
    @State private var pendingDelete: BoardGroup?
    @State private var deleteMode: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)

    private var canDelete: Bool { board.orderedGroups.count > 1 }
    private var isExpanded: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(board.orderedGroups.enumerated()), id: \.element.id) { index, group in
                                groupRow(group)
                                if index < board.orderedGroups.count - 1 {
                                    Divider()
                                }
                            }
                        }

                        if isExpanded && canDelete && !deleteMode {
                            Spacer(minLength: 24)
                            deleteButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .navigationTitle(deleteMode ? "Delete Status" : "Choose Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(deleteMode ? "Cancel" : "Done") {
                        if deleteMode {
                            deleteMode = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { showAddGroup = true }
                        .disabled(deleteMode)
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
                    deleteMode = false
                }
                .confirmationSheetPresentationStyle()
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
        .presentationDetents([.fraction(0.6), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showAddGroup) {
            newGroupSheet
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func groupRow(_ group: BoardGroup) -> some View {
        groupRowContent(group)
            .contentShape(Rectangle())
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                if deleteMode {
                    if canDelete {
                        pendingDelete = group
                    }
                    return
                }
                selection = group
                dismiss()
            }
            .draggable(beginDragGroup(group)) {
                groupRowContent(group)
                    .dynamicTypeSize(settings.textSize.dynamicType)
                    .frame(width: 320)
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

    private func groupRowContent(_ group: BoardGroup) -> some View {
        let isSelected = selection?.id == group.id
        return HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(deleteMode ? Color.red : group.colorKey.dot)
                .frame(width: 13, height: 13)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(group.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(deleteMode ? .red : .primary)

                Text("\(group.orderedTasks.count) tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if deleteMode {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
            } else if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.accent)
            }
        }
        .padding(.vertical, 16)
    }

    private func beginDragGroup(_ group: BoardGroup) -> String {
        let groupID = group.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingGroupID = groupID
        }
        return group.id.uuidString
    }

    private var deleteButton: some View {
        Button { deleteMode = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(.subheadline, weight: .bold))
                Text("Delete a Status")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var newGroupSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    SettingsCardSection("New Status") {
                        VStack(alignment: .leading, spacing: 26) {
                            HStack(spacing: 14) {
                                SettingsIconTile(systemName: "circle.fill", color: newGroupColor.foreground)
                                TextField("Status name", text: $newGroupName)
                                    .font(.system(.headline, design: .rounded))
                            }
                            ColorSwatchPicker(selection: $newGroupColor)
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
