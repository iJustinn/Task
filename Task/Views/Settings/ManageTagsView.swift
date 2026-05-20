import SwiftUI
import SwiftData

struct ManageTagsView: View {
    let board: Board
    @Environment(\.modelContext) private var context

    @State private var newName: String = ""
    @State private var newColor: ColorKey = .blue
    @State private var renamingTag: TaskTag?
    @State private var pendingDelete: TaskTag?

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
        .sheet(item: $pendingDelete) { tag in
            ConfirmationSheet(
                icon: "trash.fill",
                iconTint: .red,
                title: "Delete Tag?",
                message: "“\(tag.name)” will be removed from every task it's applied to.",
                confirmLabel: "Delete Tag"
            ) {
                context.delete(tag)
                try? context.save()
            }
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
        }
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
        SettingsCardSection("Tags") {
            if board.orderedTags.isEmpty {
                Text("No tags yet")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(board.orderedTags.enumerated()), id: \.element.id) { index, tag in
                        tagRow(tag)
                        if index < board.orderedTags.count - 1 {
                            SettingsRowDivider()
                        }
                    }
                }
            }
        }
    }

    private func tagRow(_ tag: TaskTag) -> some View {
        HStack(spacing: 14) {
            SettingsIconTile(systemName: "tag.fill", color: tag.colorKey.foreground)
            VStack(alignment: .leading, spacing: 2) {
                TagChip(name: tag.name, colorKey: tag.colorKey)
                Text("\(tag.tasks?.count ?? 0) tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { renamingTag = tag }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = tag
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func addTag() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if board.orderedTags.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            newName = ""
            return
        }
        let tag = TaskTag(name: trimmed, colorKey: newColor)
        tag.board = board
        context.insert(tag)
        try? context.save()
        newName = ""
    }

    private func delete(_ tag: TaskTag) {
        context.delete(tag)
        try? context.save()
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
