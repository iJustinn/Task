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
    @State private var pendingEdit: TaskTag?
    @State private var editMode: Bool = false
    @State private var deleteMode: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)
    /// Pre-drag `sortIndex` snapshot — captured on first hover, restored if the
    /// user cancels the drag (releases outside any row, dismisses the sheet, or
    /// goes idle for 5 s) so dirty model mutations don't leak into the next save.
    @State private var preDragSortIndex: [UUID: Int] = [:]
    @State private var reorderWatchdog: Task<Void, Never>?

    private var canDelete: Bool { !board.orderedTags.isEmpty }
    private var isExpanded: Bool { selectedDetent == .large }
    private var newTagPreviewName: String {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Tag name" : trimmed
    }

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
            .sheet(item: $pendingEdit, onDismiss: { editMode = false }) { tag in
                EditTagSheet(tag: tag)
                    .presentationDetents([.fraction(0.6), .large])
                    .presentationDragIndicator(.visible)
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

    private var sheetTitle: String {
        if deleteMode { return "Delete Tag" }
        if editMode { return "Edit Tag" }
        return "Choose Tags"
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
                if editMode {
                    pendingEdit = tag
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
            if deleteMode {
                Text(tag.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
            } else {
                TagChip(name: tag.name, colorKey: tag.colorKey)
            }

            Text("\(tag.tasks?.count ?? 0) tasks")
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

    private func beginDragTag(_ tag: TaskTag) -> String {
        let tagID = tag.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingTagID = tagID
        }
        return tag.id.uuidString
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
            SheetActionButtonLabel(title: "Edit a Tag", systemName: "pencil", tintColor: .accentColor)
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button { deleteMode = true } label: {
            SheetActionButtonLabel(title: "Delete a Tag", systemName: "trash", tintColor: .red)
        }
        .buttonStyle(.plain)
        .disabled(!canDelete)
        .opacity(canDelete ? 1 : 0.35)
    }

    private var addButton: some View {
        Button { showAddTag = true } label: {
            SheetActionButtonLabel(title: "Add a Tag", systemName: "plus", tintColor: .accentColor)
        }
        .buttonStyle(.plain)
    }

    private var newTagSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    SettingsCardSection {
                        VStack(alignment: .leading, spacing: 26) {
                            newTagPreviewField
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

    private var newTagPreviewField: some View {
        HStack {
            Spacer(minLength: 0)
            TagChip(name: newTagPreviewName, colorKey: newTagColor)
                .overlay {
                    TextField("", text: $newTagName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.clear)
                        .tint(newTagColor.foreground)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Tag name")
                }
            Spacer(minLength: 0)
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
        if let existing = board.orderedTags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            // Mirror StatusPickerSheet.addGroup: select the existing tag instead
            // of silently dropping the user's input on a duplicate name.
            if !selection.contains(where: { $0.id == existing.id }) {
                selection.append(existing)
            }
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

private struct EditTagSheet: View {
    let tag: TaskTag

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var name: String = ""
    @State private var colorKey: ColorKey = .blue
    @State private var didLoad: Bool = false

    private var previewName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Tag name" : trimmed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    SettingsCardSection {
                        VStack(alignment: .leading, spacing: 26) {
                            tagPreviewField
                            ColorSwatchPicker(selection: $colorKey)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }
            }
            .navigationTitle("Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save(); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                name = tag.name
                colorKey = tag.colorKey
                didLoad = true
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    private var tagPreviewField: some View {
        HStack {
            Spacer(minLength: 0)
            TagChip(name: previewName, colorKey: colorKey)
                .overlay {
                    TextField("", text: $name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.clear)
                        .tint(colorKey.foreground)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Tag name")
                }
            Spacer(minLength: 0)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { tag.name = trimmed }
        tag.colorKey = colorKey
        try? context.save()
    }
}
