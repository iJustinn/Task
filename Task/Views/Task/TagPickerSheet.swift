import SwiftUI
import SwiftData

struct TagPickerSheet: View {
    let board: Board
    @Binding var selection: [TaskTag]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var showAddTag = false
    @State private var newTagName: String = ""
    @State private var newTagColor: ColorKey = .blue
    @State private var draggingTagID: UUID?
    @State private var dragSessionEnded: Bool = false
    @State private var pendingDelete: TaskTag?
    @State private var deleteMode: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)
    /// Pre-drag `sortIndex` snapshot — captured on first hover, restored if the
    /// user cancels the drag (releases outside any row, dismisses the sheet, or
    /// goes idle for 5 s) so dirty model mutations don't leak into the next save.
    @State private var preDragSortIndex: [UUID: Int] = [:]
    @State private var reorderWatchdog: Task<Void, Never>?

    private var canDelete: Bool { !board.orderedTags.isEmpty }
    private var isExpanded: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(board.orderedTags.enumerated()), id: \.element.id) { index, tag in
                                tagRow(tag)
                                if index < board.orderedTags.count - 1 {
                                    Divider()
                                }
                            }
                        }

                        if board.orderedTags.isEmpty {
                            Text("Tap Add to create your first tag.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 16)
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
            .navigationTitle(deleteMode ? "Delete Tag" : "Choose Tags")
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
                    Button("Add") { showAddTag = true }
                        .disabled(deleteMode)
                }
            }
            .sheet(item: $pendingDelete) { tag in
                ConfirmationSheet(
                    icon: "trash.fill",
                    iconTint: .red,
                    title: "Delete Tag?",
                    message: "“\(tag.name)” will be removed from every task it's applied to.",
                    confirmLabel: "Delete Tag"
                ) {
                    deleteTag(tag)
                    deleteMode = false
                }
                .confirmationSheetPresentationStyle()
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
        .presentationDetents([.fraction(0.6), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showAddTag) {
            newTagSheet
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

    // MARK: - Reorder rollback

    private func captureReorderSnapshotIfNeeded() {
        guard preDragSortIndex.isEmpty else { return }
        var snap: [UUID: Int] = [:]
        for tag in board.orderedTags { snap[tag.id] = tag.sortIndex }
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
            for tag in board.orderedTags {
                if let original = preDragSortIndex[tag.id], tag.sortIndex != original {
                    tag.sortIndex = original
                }
            }
        }
        try? context.save()
        preDragSortIndex.removeAll()
        reorderWatchdog?.cancel()
        reorderWatchdog = nil
    }

    private func tagRow(_ tag: TaskTag) -> some View {
        tagRowContent(tag)
            .contentShape(Rectangle())
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                if deleteMode {
                    pendingDelete = tag
                    return
                }
                toggle(tag)
            }
            .draggable(beginDragTag(tag)) {
                tagRowContent(tag)
                    .dynamicTypeSize(settings.textSize.dynamicType)
                    .frame(width: 320)
            }
            .onDrop(
                of: StringMoveDropDelegate.acceptedTypes,
                delegate: ReorderDropDelegate<TaskTag>(
                    target: tag,
                    ordered: { board.orderedTags },
                    onCommit: { try? context.save() },
                    onBeginDrag: { captureReorderSnapshotIfNeeded() },
                    onTick: { rearmReorderWatchdogIfDragging() },
                    onCompleteDrag: { completeReorder() },
                    draggingID: $draggingTagID,
                    dragSessionEnded: $dragSessionEnded
                )
            )
    }

    private func tagRowContent(_ tag: TaskTag) -> some View {
        let isSelected = selection.contains(where: { $0.id == tag.id })
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "tag.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(deleteMode ? .red : tag.colorKey.foreground)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(tag.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(deleteMode ? .red : .primary)

                Text("\(tag.tasks?.count ?? 0) tasks")
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

    private func beginDragTag(_ tag: TaskTag) -> String {
        let tagID = tag.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingTagID = tagID
        }
        return tag.id.uuidString
    }

    private var deleteButton: some View {
        Button { deleteMode = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(.subheadline, weight: .bold))
                Text("Delete a Tag")
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

    private var newTagSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    SettingsCardSection("New Tag") {
                        VStack(alignment: .leading, spacing: 26) {
                            HStack(spacing: 14) {
                                SettingsIconTile(systemName: "tag.fill", color: newTagColor.foreground)
                                TextField("Tag name", text: $newTagName)
                                    .font(.system(.headline, design: .rounded))
                            }
                            ColorSwatchPicker(selection: $newTagColor)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showAddTag = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addTag() }
                        .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func toggle(_ tag: TaskTag) {
        if let idx = selection.firstIndex(where: { $0.id == tag.id }) {
            selection.remove(at: idx)
        } else {
            selection.append(tag)
        }
    }

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if board.orderedTags.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            newTagName = ""
            showAddTag = false
            return
        }
        let sortIndex = (board.orderedTags.last?.sortIndex ?? -1) + 1
        let tag = TaskTag(name: trimmed, colorKey: newTagColor, sortIndex: sortIndex)
        tag.board = board
        context.insert(tag)
        try? context.save()
        selection.append(tag)
        newTagName = ""
        showAddTag = false
    }

    private func deleteTag(_ tag: TaskTag) {
        selection.removeAll(where: { $0.id == tag.id })
        context.delete(tag)
        try? context.save()
    }
}

