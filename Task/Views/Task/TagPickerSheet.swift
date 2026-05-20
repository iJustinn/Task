import SwiftUI
import SwiftData

struct TagPickerSheet: View {
    let board: Board
    @Binding var selection: [TaskTag]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showAddTag = false
    @State private var newTagName: String = ""
    @State private var newTagColor: ColorKey = .blue

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(board.orderedTags, id: \.id) { tag in
                            Button {
                                toggle(tag)
                            } label: {
                                GridTile(
                                    title: tag.name,
                                    subtitle: "\(tag.tasks?.count ?? 0) tasks",
                                    systemImage: "tag.fill",
                                    tintColor: tag.colorKey.foreground,
                                    isSelected: selection.contains(where: { $0.id == tag.id })
                                )
                            }
                            .buttonStyle(.plain)
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
                    .padding(.bottom, 30)

                    if board.orderedTags.isEmpty {
                        Text("Tap New to create your first tag.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
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
        }
        .sheet(isPresented: $showAddTag) {
            newTagSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
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
}
