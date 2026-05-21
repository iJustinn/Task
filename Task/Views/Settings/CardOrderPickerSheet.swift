import SwiftUI

struct CardOrderPickerSheet: View {
    let board: Board
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        sortBySection
                        orderSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Sort")
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

    private var sortBySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sort By")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(CardSortField.allCases) { field in
                    Button {
                        board.cardSortField = field
                        board.updatedAt = Date()
                        try? context.save()
                    } label: {
                        GridTile(
                            title: field.label,
                            subtitle: field.descriptor,
                            systemImage: field.systemImage,
                            tintColor: field.tintColor,
                            isSelected: board.cardSortField == field
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var orderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Order")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(CardSortDirection.allCases) { dir in
                    Button {
                        board.cardSortDirection = dir
                        board.updatedAt = Date()
                        try? context.save()
                    } label: {
                        GridTile(
                            title: dir.label,
                            subtitle: dir.descriptor,
                            systemImage: dir.systemImage,
                            tintColor: dir.tintColor,
                            isSelected: board.cardSortDirection == dir
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(board.cardSortField == .manual)
                }
            }
            .opacity(board.cardSortField == .manual ? 0.45 : 1)

            if board.cardSortField == .manual {
                Text("Order doesn't apply to Manual — drag a card to reorder it inside its group.")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }
}
