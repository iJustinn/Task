import SwiftUI
import SwiftData

struct ManageGroupsView: View {
    let board: Board
    @Environment(\.modelContext) private var context

    @State private var newName: String = ""
    @State private var newColor: ColorKey = .purple
    @State private var editingGroup: BoardGroup?
    @State private var isReordering: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    newGroupSection
                    groupsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 60)
            }
        }
        .navigationTitle("Manage Groups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isReordering ? "Done" : "Reorder") {
                    withAnimation { isReordering.toggle() }
                }
            }
        }
        .sheet(item: $editingGroup) { group in
            GroupMenuSheet(group: group, board: board)
        }
    }

    private var newGroupSection: some View {
        SettingsCardSection("New Group") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    SettingsIconTile(systemName: "plus.circle.fill", color: newColor.foreground)
                    TextField("Group name", text: $newName)
                        .font(.system(.headline, design: .rounded))
                }
                ColorSwatchPicker(selection: $newColor)
                    .padding(.leading, 58)
                Button(action: addGroup) {
                    Text("Add Group")
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

    private var groupsSection: some View {
        SettingsCardSection("Groups") {
            VStack(spacing: 0) {
                ForEach(Array(board.orderedGroups.enumerated()), id: \.element.id) { index, group in
                    groupRow(group, index: index)
                    if index < board.orderedGroups.count - 1 {
                        SettingsRowDivider()
                    }
                }
            }
        }
    }

    private func groupRow(_ group: BoardGroup, index: Int) -> some View {
        HStack(spacing: 12) {
            SettingsIconTile(systemName: "circle.fill", color: group.colorKey.foreground)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                Text("\(group.orderedTasks.count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isReordering {
                HStack(spacing: 8) {
                    Button {
                        moveGroup(at: index, by: -1)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(.headline, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)
                    Button {
                        moveGroup(at: index, by: 1)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(.headline, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= board.orderedGroups.count - 1)
                }
            } else {
                Button {
                    editingGroup = group
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isReordering { editingGroup = group }
        }
    }

    private func addGroup() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let sortIndex = (board.orderedGroups.last?.sortIndex ?? -1) + 1
        let group = BoardGroup(name: trimmed, colorKey: newColor, sortIndex: sortIndex)
        group.board = board
        context.insert(group)
        try? context.save()
        newName = ""
    }

    private func moveGroup(at index: Int, by delta: Int) {
        var groups = board.orderedGroups
        let newIndex = index + delta
        guard newIndex >= 0 && newIndex < groups.count else { return }
        groups.swapAt(index, newIndex)
        for (i, g) in groups.enumerated() { g.sortIndex = i }
        try? context.save()
    }
}
