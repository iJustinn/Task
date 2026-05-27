import SwiftUI

struct CardOrderPickerSheet: View {
    let board: Board
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel
    private var isMacLayout: Bool { PlatformLayout.prefersMacInterface }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(isMacLayout ? .systemGroupedBackground : .systemBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: isMacLayout ? 18 : 24) {
                        sortBySection
                        orderSection
                    }
                    .padding(.horizontal, isMacLayout ? 24 : 20)
                    .padding(.top, isMacLayout ? 16 : 8)
                    .padding(.bottom, isMacLayout ? 28 : 24)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .navigationTitle("Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
        .taskMacSheetFrame(width: 560, minHeight: 460)
    }

    private var sortBySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sort By")
                .font(.system(size: isMacLayout ? 20 : 29, weight: .bold))
                .foregroundColor(.primary)
            LazyVStack(spacing: 0) {
                ForEach(Array(CardSortField.allCases.enumerated()), id: \.element.id) { index, field in
                    sortFieldRow(field)
                    if index < CardSortField.allCases.count - 1 {
                        Divider().padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    private var orderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Order")
                .font(.system(size: isMacLayout ? 20 : 29, weight: .bold))
                .foregroundColor(.primary)
            LazyVStack(spacing: 0) {
                ForEach(Array(CardSortDirection.allCases.enumerated()), id: \.element.id) { index, direction in
                    sortDirectionRow(direction)
                    if index < CardSortDirection.allCases.count - 1 {
                        Divider().padding(.horizontal, 8)
                    }
                }
            }
            .opacity(board.cardSortField == .manual ? 0.45 : 1)

            if board.cardSortField == .manual {
                Text("Order doesn't apply to Manual — drag a card to reorder it inside its group.")
                    .font(.system(.footnote).weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private func sortFieldRow(_ field: CardSortField) -> some View {
        Button {
            board.cardSortField = field
            board.updatedAt = Date()
            try? context.save()
        } label: {
            sortRowContent(
                title: field.label,
                subtitle: field.descriptor,
                systemImage: field.systemImage,
                tint: field.tintColor,
                isSelected: board.cardSortField == field
            )
        }
        .buttonStyle(.plain)
    }

    private func sortDirectionRow(_ direction: CardSortDirection) -> some View {
        Button {
            board.cardSortDirection = direction
            board.updatedAt = Date()
            try? context.save()
        } label: {
            sortRowContent(
                title: direction.label,
                subtitle: direction.descriptor,
                systemImage: direction.systemImage,
                tint: direction.tintColor,
                isSelected: board.cardSortDirection == direction
            )
        }
        .buttonStyle(.plain)
        .disabled(board.cardSortField == .manual)
    }

    private func sortRowContent(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isSelected: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.accent)
            }
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}
