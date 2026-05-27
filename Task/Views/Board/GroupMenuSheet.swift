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
    private var isMacLayout: Bool { PlatformLayout.prefersMacInterface }
    private var isExpanded: Bool { isMacLayout || selectedDetent == .large }
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
                Color(isMacLayout ? .systemGroupedBackground : .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if isMacLayout {
                        macSheetHeader
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: isMacLayout ? 18 : 22) {
                            nameAndColorSection
                            if isExpanded && canDelete {
                                Spacer(minLength: 24)
                                deleteSection
                            }
                        }
                        .padding(.horizontal, isMacLayout ? 24 : 16)
                        .padding(.top, isMacLayout ? 10 : 10)
                        .padding(.bottom, isMacLayout ? 28 : 24)
                        .frame(minHeight: proxy.size.height - (isMacLayout ? 62 : 0), alignment: .topLeading)
                    }
                }
            }
            .navigationTitle(isMacLayout ? "" : "Edit Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isMacLayout {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { save(); dismiss() }
                    }
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
        .taskMacSheetFrame(width: 540, minHeight: 460)
        .taskSheetPresentation(selection: $selectedDetent, macHeight: 520)
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    private var macSheetHeader: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 12)

            Text("Edit Status")
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 12)

            Button("Save") { save(); dismiss() }
                .frame(width: 82, alignment: .trailing)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
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
