import SwiftUI

struct StatusPickerSheet: View {
    let board: Board
    @Binding var selection: BoardGroup?
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
                                selection = group
                                dismiss()
                            } label: {
                                GridTile(
                                    title: group.name,
                                    subtitle: "\(group.orderedTasks.count) tasks",
                                    dotColor: group.colorKey.dot,
                                    tintColor: group.colorKey.foreground,
                                    isSelected: selection?.id == group.id
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
            .navigationTitle("Choose Status")
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
