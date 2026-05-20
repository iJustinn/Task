import SwiftUI
import SwiftData

struct GroupMenuSheet: View {
    let group: BoardGroup
    let board: Board
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var colorKey: ColorKey = .purple
    @State private var didLoad: Bool = false
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        nameAndColorSection
                        deleteSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save(); dismiss() }.fontWeight(.bold)
                }
            }
            .onAppear {
                if !didLoad {
                    name = group.name
                    colorKey = group.colorKey
                    didLoad = true
                }
            }
            .sheet(isPresented: $showDeleteConfirm) {
                ConfirmationSheet(
                    icon: "trash.fill",
                    iconTint: .red,
                    title: "Delete Group?",
                    message: "This group will be removed. Its tasks will move to the first remaining group.",
                    confirmLabel: "Delete Group"
                ) {
                    deleteAndDismiss()
                }
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var nameAndColorSection: some View {
        SettingsCardSection("Group") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    SettingsIconTile(systemName: "circle.fill", color: colorKey.foreground)
                    TextField("Group name", text: $name)
                        .font(.system(.headline, design: .rounded))
                }
                ColorSwatchPicker(selection: $colorKey).padding(.leading, 58)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var deleteSection: some View {
        SettingsCardSection {
            Button {
                showDeleteConfirm = true
            } label: {
                Text("Delete Group")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(board.orderedGroups.count <= 1 ? .secondary : .red)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(board.orderedGroups.count <= 1)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { group.name = trimmed }
        group.colorKey = colorKey
        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
    }

    private func deleteAndDismiss() {
        let groups = board.orderedGroups
        guard groups.count > 1 else { return }
        let remaining = groups.filter { $0.id != group.id }
        if let fallback = remaining.first, let tasks = group.tasks {
            for task in tasks {
                task.group = fallback
                task.sortIndex = (fallback.orderedTasks.last?.sortIndex ?? -1) + 1
            }
        }
        context.delete(group)
        for (idx, g) in remaining.enumerated() { g.sortIndex = idx }
        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        dismiss()
    }
}
