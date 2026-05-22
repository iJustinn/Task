import SwiftUI
import SwiftData

struct GroupMenuSheet: View {
    let group: BoardGroup
    let board: Board
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var name: String = ""
    @State private var colorKey: ColorKey = .purple
    @State private var didLoad: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)

    private var canDelete: Bool { board.orderedGroups.count > 1 }
    private var isExpanded: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        nameAndColorSection
                        if isExpanded && canDelete {
                            Spacer(minLength: 24)
                            deleteSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save(); dismiss() }
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
                    title: "Delete Status?",
                    message: "This status will be removed. Its tasks will move to the first remaining status.",
                    confirmLabel: "Delete Status"
                ) {
                    deleteAndDismiss()
                }
                .confirmationSheetPresentationStyle()
            }
        }
        .presentationDetents([.fraction(0.6), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    private var nameAndColorSection: some View {
        SettingsCardSection("Status") {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 14) {
                    SettingsIconTile(systemName: "circle.fill", color: colorKey.foreground)
                    TextField("Status name", text: $name)
                        .font(.system(.headline, design: .rounded))
                }
                ColorSwatchPicker(selection: $colorKey)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var deleteSection: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(.subheadline, weight: .bold))
                Text("Delete Status")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            // Capture the fallback's max sortIndex once. Reading
            // `fallback.orderedTasks.last?.sortIndex` inside the loop returns the same
            // value for every iteration (the inverse relationship doesn't visibly
            // update before the next read), so every moved task would otherwise get
            // the same sortIndex.
            var base = (fallback.orderedTasks.last?.sortIndex ?? -1)
            for task in tasks {
                task.group = fallback
                base += 1
                task.sortIndex = base
            }
        }
        // If this group was the board's default-status, point the default at the
        // fallback before deletion so exports don't preserve a dangling ID.
        if board.defaultGroupUUID == group.id {
            board.defaultGroupUUID = remaining.first?.id
        }
        context.delete(group)
        for (idx, g) in remaining.enumerated() { g.sortIndex = idx }
        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        dismiss()
    }
}
