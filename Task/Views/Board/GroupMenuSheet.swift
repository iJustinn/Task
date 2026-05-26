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
    @State private var isDefaultStatus: Bool = false
    @State private var cardDisplayLimit: CardDisplayLimit = .five
    @State private var didLoad: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)

    private var canDelete: Bool { board.orderedGroups.count > 1 }
    private var isExpanded: Bool { selectedDetent == .large }
    private var canChangeDefaultStatus: Bool { board.orderedGroups.count > 1 }
    private var currentDefaultStatusName: String {
        board.defaultGroup?.name ?? String(localized: "None")
    }
    private var previewName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Status name" : trimmed
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(.systemBackground)
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
            .navigationTitle("Edit Status")
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
                    isDefaultStatus = board.defaultGroup?.id == group.id
                    cardDisplayLimit = group.cardDisplayLimit
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
        SettingsCardSection {
            VStack(alignment: .leading, spacing: 26) {
                statusPreviewField
                ColorSwatchPicker(selection: $colorKey)
                Divider()
                defaultStatusSection
                Divider()
                cardDisplayLimitSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var defaultStatusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isDefaultStatus) {
                Text("Default for New Tasks")
                    .font(.system(.headline))
            }
            .toggleStyle(.switch)
            .disabled(!canChangeDefaultStatus)

            Text("Current default: \(currentDefaultStatusName)")
                .font(.system(.footnote))
                .foregroundStyle(.secondary)
        }
    }

    private var cardDisplayLimitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cards per Column")
                .font(.system(.headline))

            Picker("Cards per Column", selection: $cardDisplayLimit) {
                ForEach(CardDisplayLimit.allCases) { limit in
                    Text(limit.label).tag(limit)
                }
            }
            .pickerStyle(.segmented)
            .frame(height: 32)
        }
    }

    private var statusPreviewField: some View {
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
                        .accessibilityLabel("Status name")
                }
            Spacer(minLength: 0)
        }
    }

    private var deleteSection: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            SheetActionButtonLabel(title: "Delete Status", systemName: "trash", tintColor: .red, fillsWidth: true)
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { group.name = trimmed }
        group.colorKey = colorKey
        group.cardDisplayLimit = cardDisplayLimit
        board.setDefaultGroup(group, enabled: isDefaultStatus)
        board.updatedAt = Date()
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
