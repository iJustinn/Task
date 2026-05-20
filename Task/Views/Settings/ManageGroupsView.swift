import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ManageGroupsView: View {
    let board: Board
    @Environment(\.modelContext) private var context

    @State private var newName: String = ""
    @State private var newColor: ColorKey = .purple
    @State private var editingGroup: BoardGroup?
    @State private var draggingGroupID: UUID?
    @State private var dragSessionEnded: Bool = false

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
        .sheet(item: $editingGroup) { group in
            GroupMenuSheet(group: group, board: board)
        }
        .onDrop(
            of: StringMoveDropDelegate.acceptedTypes,
            delegate: GroupReorderFallbackDelegate(
                draggingGroupID: $draggingGroupID,
                dragSessionEnded: $dragSessionEnded
            )
        )
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Groups")
                .font(.system(.title3, design: .default).weight(.bold))
                .padding(.leading, 4)
            VStack(spacing: 8) {
                ForEach(board.orderedGroups, id: \.id) { group in
                    groupRow(group)
                }
            }
        }
    }

    private func groupRow(_ group: BoardGroup) -> some View {
        groupCardContent(group)
            .onTapGesture { editingGroup = group }
            .draggable(beginDrag(of: group)) {
                groupCardContent(group)
                    .frame(maxWidth: 360)
            }
            .onDrop(
                of: StringMoveDropDelegate.acceptedTypes,
                delegate: GroupReorderDropDelegate(
                    target: group,
                    board: board,
                    context: context,
                    draggingGroupID: $draggingGroupID,
                    dragSessionEnded: $dragSessionEnded
                )
            )
    }

    private func beginDrag(of group: BoardGroup) -> String {
        let groupID = group.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingGroupID = groupID
        }
        return group.id.uuidString
    }

    private func groupCardContent(_ group: BoardGroup) -> some View {
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
}

private struct GroupReorderFallbackDelegate: DropDelegate {
    @Binding var draggingGroupID: UUID?
    @Binding var dragSessionEnded: Bool

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingGroupID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        return false
    }
}

private struct GroupReorderDropDelegate: DropDelegate {
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
