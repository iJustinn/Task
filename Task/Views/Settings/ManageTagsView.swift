import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ManageTagsView: View {
    let board: Board
    @Environment(\.modelContext) private var context

    @State private var newName: String = ""
    @State private var newColor: ColorKey = .blue
    @State private var renamingTag: TaskTag?
    @State private var draggingTagID: UUID?
    @State private var dragSessionEnded: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    newTagSection
                    tagsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 60)
            }
        }
        .navigationTitle("Manage Tags")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $renamingTag) { tag in
            TagEditSheet(tag: tag)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onDrop(
            of: StringMoveDropDelegate.acceptedTypes,
            delegate: TagReorderFallbackDelegate(
                draggingTagID: $draggingTagID,
                dragSessionEnded: $dragSessionEnded
            )
        )
    }

    private var newTagSection: some View {
        SettingsCardSection("New Tag") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    SettingsIconTile(systemName: "tag.fill", color: newColor.foreground)
                    TextField("Tag name", text: $newName)
                        .font(.system(.headline, design: .rounded))
                }
                ColorSwatchPicker(selection: $newColor).padding(.leading, 58)
                Button(action: addTag) {
                    Text("Add Tag")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(newName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.18) : Color.accentColor.opacity(0.15))
                        )
                        .foregroundColor(newName.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.system(.title3, design: .default).weight(.bold))
                .padding(.leading, 4)
            if board.orderedTags.isEmpty {
                Text("No tags yet")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
            } else {
                VStack(spacing: 8) {
                    ForEach(board.orderedTags, id: \.id) { tag in
                        tagRow(tag)
                    }
                }
            }
        }
    }

    private func tagRow(_ tag: TaskTag) -> some View {
        tagCardContent(tag)
            .onTapGesture { renamingTag = tag }
            .draggable(beginDragTag(of: tag)) {
                tagCardContent(tag)
                    .frame(maxWidth: 360)
            }
            .onDrop(
                of: StringMoveDropDelegate.acceptedTypes,
                delegate: TagReorderDropDelegate(
                    target: tag,
                    board: board,
                    context: context,
                    draggingTagID: $draggingTagID,
                    dragSessionEnded: $dragSessionEnded
                )
            )
    }

    private func tagCardContent(_ tag: TaskTag) -> some View {
        HStack(spacing: 14) {
            SettingsIconTile(systemName: "tag.fill", color: tag.colorKey.foreground)
            VStack(alignment: .leading, spacing: 2) {
                TagChip(name: tag.name, colorKey: tag.colorKey)
                Text("\(tag.tasks?.count ?? 0) tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.45))
            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func beginDragTag(of tag: TaskTag) -> String {
        let tagID = tag.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingTagID = tagID
        }
        return tag.id.uuidString
    }

    private func addTag() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if board.orderedTags.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            newName = ""
            return
        }
        let sortIndex = (board.orderedTags.last?.sortIndex ?? -1) + 1
        let tag = TaskTag(name: trimmed, colorKey: newColor, sortIndex: sortIndex)
        tag.board = board
        context.insert(tag)
        try? context.save()
        newName = ""
    }
}

private struct TagReorderFallbackDelegate: DropDelegate {
    @Binding var draggingTagID: UUID?
    @Binding var dragSessionEnded: Bool

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingTagID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        return false
    }
}

private struct TagReorderDropDelegate: DropDelegate {
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

private struct TagEditSheet: View {
    let tag: TaskTag
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name: String = ""
    @State private var color: ColorKey = .blue
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        SettingsCardSection("Edit Tag") {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 14) {
                                    SettingsIconTile(systemName: "tag.fill", color: color.foreground)
                                    TextField("Tag name", text: $name)
                                        .font(.system(.headline, design: .rounded))
                                }
                                ColorSwatchPicker(selection: $color).padding(.leading, 58)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        SettingsCardSection {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                Text("Delete Tag")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, minHeight: 56)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.fontWeight(.bold)
                }
            }
            .onAppear {
                if !didLoad {
                    name = tag.name
                    color = tag.colorKey
                    didLoad = true
                }
            }
            .sheet(isPresented: $showDeleteConfirm) {
                ConfirmationSheet(
                    icon: "trash.fill",
                    iconTint: .red,
                    title: "Delete Tag?",
                    message: "“\(tag.name)” will be removed from every task it's applied to.",
                    confirmLabel: "Delete Tag"
                ) {
                    context.delete(tag)
                    try? context.save()
                    dismiss()
                }
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { tag.name = trimmed }
        tag.colorKey = color
        try? context.save()
        dismiss()
    }
}
