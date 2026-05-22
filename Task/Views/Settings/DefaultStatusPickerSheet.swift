import SwiftUI

struct DefaultStatusPickerSheet: View {
    let board: Board
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(board.orderedGroups.enumerated()), id: \.element.id) { index, group in
                                statusRow(group)
                                if index < board.orderedGroups.count - 1 {
                                    Divider().padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .navigationTitle("Default Status")
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
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    private func statusRow(_ group: BoardGroup) -> some View {
        Button {
            board.defaultGroupUUID = group.id
            board.updatedAt = Date()
            try? context.save()
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .fill(group.colorKey.dot)
                    .frame(width: 13, height: 13)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 5) {
                    Text(group.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(group.orderedTasks.count) tasks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if board.defaultGroup?.id == group.id {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.accent)
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
