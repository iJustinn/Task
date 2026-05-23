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
    @State private var pendingEdit: BoardGroup?
    @State private var editMode: Bool = false
    @State private var deleteMode: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)
    /// Pre-drag `sortIndex` snapshot — captured on first hover, restored if the
    /// user cancels the drag (releases outside any row, dismisses the sheet, or
    /// goes idle for 5 s) so dirty model mutations don't leak into the next save.
    @State private var preDragSortIndex: [UUID: Int] = [:]
    @State private var reorderWatchdog: Task<Void, Never>?

    private var canDelete: Bool { board.orderedGroups.count > 1 }
    private var isExpanded: Bool { selectedDetent == .large }
    private var newGroupPreviewName: String {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Status name" : trimmed
    }

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

                        if isExpanded && !deleteMode && !editMode {
                            Spacer(minLength: 24)
                            bottomActionRow
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if deleteMode {
                            deleteMode = false
                        } else if editMode {
                            editMode = false
                        } else {
                            dismiss()
                        }
                    }
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
                    deleteMode = false
                }
                .confirmationSheetPresentationStyle()
            }
            .sheet(item: $pendingEdit, onDismiss: { editMode = false }) { group in
                GroupMenuSheet(group: group, board: board)
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
        .onDisappear {
            if !preDragSortIndex.isEmpty {
                rollbackReorderIfPending()
            }
            reorderWatchdog?.cancel()
            reorderWatchdog = nil
        }
    }

    private var sheetTitle: String {
        if deleteMode { return "Delete Status" }
        if editMode { return "Edit Status" }
        return "Choose Status"
    }

    // MARK: - Reorder rollback

    private func captureReorderSnapshotIfNeeded() {
        guard preDragSortIndex.isEmpty else { return }
        var snap: [UUID: Int] = [:]
        for group in board.orderedGroups { snap[group.id] = group.sortIndex }
        preDragSortIndex = snap
        armReorderWatchdog()
    }

    private func rearmReorderWatchdogIfDragging() {
        guard !preDragSortIndex.isEmpty else { return }
        armReorderWatchdog()
    }

    private func armReorderWatchdog() {
        reorderWatchdog?.cancel()
        reorderWatchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if Task.isCancelled { return }
            rollbackReorderIfPending()
        }
    }

    private func completeReorder() {
        reorderWatchdog?.cancel()
        reorderWatchdog = nil
        preDragSortIndex.removeAll()
    }

    private func rollbackReorderIfPending() {
        guard !preDragSortIndex.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            for group in board.orderedGroups {
                if let original = preDragSortIndex[group.id], group.sortIndex != original {
                    group.sortIndex = original
                }
            }
        }
        try? context.save()
        preDragSortIndex.removeAll()
        reorderWatchdog?.cancel()
        reorderWatchdog = nil
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
                if editMode {
                    pendingEdit = group
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
                delegate: ReorderDropDelegate<BoardGroup>(
                    target: group,
                    ordered: { board.orderedGroups },
                    onCommit: { try? context.save() },
                    onBeginDrag: { captureReorderSnapshotIfNeeded() },
                    onTick: { rearmReorderWatchdogIfDragging() },
                    onCompleteDrag: { completeReorder() },
                    draggingID: $draggingGroupID,
                    dragSessionEnded: $dragSessionEnded
                )
            )
    }

    private func groupRowContent(_ group: BoardGroup) -> some View {
        let isSelected = selection?.id == group.id
        return HStack(alignment: .center, spacing: 12) {
            if deleteMode {
                Text(group.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
            } else {
                TagChip(name: group.name, colorKey: group.colorKey)
            }

            Text("\(group.orderedTasks.count) tasks")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            if deleteMode {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
            } else if editMode {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.accent)
            } else if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.accent)
            }
        }
        .padding(.vertical, 20)
    }

    private func beginDragGroup(_ group: BoardGroup) -> String {
        let groupID = group.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingGroupID = groupID
        }
        return group.id.uuidString
    }

    private var bottomActionRow: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 34) {
                    editButton
                    addButton
                }
                .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }
            HStack {
                Spacer(minLength: 0)
                deleteButton
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
            }
        }
    }

    private var editButton: some View {
        Button { editMode = true } label: {
            SheetActionButtonLabel(title: "Edit a Status", systemName: "pencil", tintColor: .accentColor)
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button { deleteMode = true } label: {
            SheetActionButtonLabel(title: "Delete a Status", systemName: "trash", tintColor: .red)
        }
        .buttonStyle(.plain)
        .disabled(!canDelete)
        .opacity(canDelete ? 1 : 0.35)
    }

    private var addButton: some View {
        Button { showAddGroup = true } label: {
            SheetActionButtonLabel(title: "Add a Status", systemName: "plus", tintColor: .accentColor)
        }
        .buttonStyle(.plain)
    }

    private var newGroupSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    SettingsCardSection {
                        VStack(alignment: .leading, spacing: 26) {
                            newGroupPreviewField
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

    private var newGroupPreviewField: some View {
        HStack {
            Spacer(minLength: 0)
            TagChip(name: newGroupPreviewName, colorKey: newGroupColor)
                .overlay {
                    TextField("", text: $newGroupName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.clear)
                        .tint(newGroupColor.foreground)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Status name")
                }
            Spacer(minLength: 0)
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
