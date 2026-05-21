import SwiftUI

struct DefaultStatusPickerSheet: View {
    let board: Board
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

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
                        ForEach(board.orderedGroups, id: \.id) { group in
                            Button {
                                board.defaultGroupID = group.id.uuidString
                                board.updatedAt = Date()
                                try? context.save()
                                dismiss()
                            } label: {
                                GridTile(
                                    title: group.name,
                                    subtitle: "\(group.orderedTasks.count) tasks",
                                    dotColor: group.colorKey.dot,
                                    tintColor: group.colorKey.foreground,
                                    isSelected: board.defaultGroup?.id == group.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
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
    }
}
