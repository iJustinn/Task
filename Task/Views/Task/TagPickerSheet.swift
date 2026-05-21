import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct TagPickerSheet: View {
    let board: Board
    @Binding var selection: [TaskTag]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showAddTag = false
    @State private var newTagName: String = ""
    @State private var newTagColor: ColorKey = .blue
    @State private var draggingTagID: UUID?
    @State private var dragSessionEnded: Bool = false
    @State private var pendingDelete: TaskTag?
    @State private var deleteZoneHovered: Bool = false
    @State private var dragOverScreen: Bool = false
    @State private var showDeleteZone: Bool = false
    @State private var hideDeleteZoneTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(board.orderedTags, id: \.id) { tag in
                            tagTile(tag)
                        }

                        Button {
                            showAddTag = true
                        } label: {
                            GridTile(
                                title: "New",
                                subtitle: "Create tag",
                                systemImage: "plus",
                                tintColor: .accentColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 120)

                    if board.orderedTags.isEmpty {
                        Text("Tap New to create your first tag.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }

                if showDeleteZone {
                    deleteDropZone
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onDrop(of: StringMoveDropDelegate.acceptedTypes, isTargeted: $dragOverScreen) { _ in
                draggingTagID = nil
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
            .navigationTitle("Choose Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
                }
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAddTag) {
            newTagSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func tagTile(_ tag: TaskTag) -> some View {
        GridTile(
            title: tag.name,
            subtitle: "\(tag.tasks?.count ?? 0) tasks",
            systemImage: "tag.fill",
            tintColor: tag.colorKey.foreground,
            isSelected: selection.contains(where: { $0.id == tag.id })
        )
        .contentShape(Rectangle())
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { toggle(tag) }
        .draggable(beginDragTag(tag)) {
            GridTile(
                title: tag.name,
                subtitle: "\(tag.tasks?.count ?? 0) tasks",
                systemImage: "tag.fill",
                tintColor: tag.colorKey.foreground
            )
            .frame(width: 120)
        }
        .onDrop(
            of: StringMoveDropDelegate.acceptedTypes,
            delegate: TagPickerReorderDropDelegate(
                target: tag,
                board: board,
                context: context,
                draggingTagID: $draggingTagID,
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
            delegate: TagDeleteDropDelegate(
                draggingTagID: $draggingTagID,
                dragSessionEnded: $dragSessionEnded,
                hovered: $deleteZoneHovered,
                resolveTag: { id in board.orderedTags.first(where: { $0.id == id }) },
                onDelete: { tag in pendingDelete = tag }
            )
        )
    }

    private func beginDragTag(_ tag: TaskTag) -> String {
        let tagID = tag.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingTagID = tagID
        }
        return tag.id.uuidString
    }

    private var newTagSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    SettingsCardSection("New Tag") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                SettingsIconTile(systemName: "tag.fill", color: newTagColor.foreground)
                                TextField("Tag name", text: $newTagName)
                                    .font(.system(.headline, design: .rounded))
                            }
                            ColorSwatchPicker(selection: $newTagColor).padding(.leading, 58)
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

private struct TagPickerReorderDropDelegate: DropDelegate {
    let target: TaskTag
    let board: Board
    let context: ModelContext
    @Binding var draggingTagID: UUID?
    @Binding var dragSessionEnded: Bool

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let id = draggingTagID, id != target.id else { return }
        applyMove(draggedID: id)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let id = draggingTagID {
            applyMove(draggedID: id)
            try? context.save()
        }
        draggingTagID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        return true
    }

    private func applyMove(draggedID: UUID) {
        guard draggedID != target.id else { return }
        var ordered = board.orderedTags
        guard let from = ordered.firstIndex(where: { $0.id == draggedID }),
              let to = ordered.firstIndex(where: { $0.id == target.id }),
              from != to else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            let item = ordered.remove(at: from)
            ordered.insert(item, at: to)
            for (i, t) in ordered.enumerated() {
                if t.sortIndex != i {
                    t.sortIndex = i
                }
            }
        }
    }
}

private struct TagDeleteDropDelegate: DropDelegate {
    @Binding var draggingTagID: UUID?
    @Binding var dragSessionEnded: Bool
    @Binding var hovered: Bool
    let resolveTag: (UUID) -> TaskTag?
    let onDelete: (TaskTag) -> Void

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
        let draggedID = draggingTagID
        hovered = false
        draggingTagID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        if let id = draggedID, let tag = resolveTag(id) {
            DispatchQueue.main.async {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                onDelete(tag)
            }
            return true
        }
        return false
    }
}
