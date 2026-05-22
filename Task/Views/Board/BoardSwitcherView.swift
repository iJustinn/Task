import SwiftUI
import SwiftData

struct BoardSwitcherView: View {
    let activeBoardID: UUID
    var onPickBoard: (UUID) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel
    @Query(sort: \Board.sortIndex) private var boards: [Board]

    @State private var pendingDelete: Board?
    @State private var draggingBoardID: UUID?
    @State private var dragSessionEnded: Bool = false
    @State private var deleteMode: Bool = false
    @State private var selectedDetent: PresentationDetent = .fraction(0.6)

    private var canDelete: Bool { boards.count > 1 }
    private var isExpanded: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(.systemBackground)
                    .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(boards.enumerated()), id: \.element.id) { index, board in
                                boardRow(board)
                                if index < boards.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        if isExpanded && canDelete && !deleteMode {
                            Spacer(minLength: 24)
                            deleteButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .navigationTitle(deleteMode ? "Delete Board" : "Boards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(deleteMode ? "Cancel" : "Done") {
                        if deleteMode {
                            deleteMode = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addBoard() }
                        .disabled(deleteMode)
                }
            }
            .sheet(item: $pendingDelete) { board in
                ConfirmationSheet(
                    icon: "trash.fill",
                    iconTint: .red,
                    title: "Delete Board?",
                    message: "“\(board.title)” and all its groups, tags, and tasks will be removed.",
                    confirmLabel: "Delete Board"
                ) {
                    deleteBoard(board)
                    deleteMode = false
                }
                .confirmationSheetPresentationStyle()
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
        .presentationDetents([.fraction(0.6), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private func boardRow(_ board: Board) -> some View {
        boardRowContent(board)
            .contentShape(Rectangle())
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                if deleteMode {
                    if canDelete {
                        pendingDelete = board
                    }
                    return
                }
                onPickBoard(board.id)
                dismiss()
            }
            .draggable(beginDrag(of: board)) {
                boardRowContent(board)
                    .dynamicTypeSize(settings.textSize.dynamicType)
                    .frame(width: 320)
            }
            .onDrop(
                of: StringMoveDropDelegate.acceptedTypes,
                delegate: BoardReorderDropDelegate(
                    target: board,
                    boards: boards,
                    context: context,
                    draggingBoardID: $draggingBoardID,
                    dragSessionEnded: $dragSessionEnded
                )
            )
    }

    private func boardRowContent(_ board: Board) -> some View {
        let isActive = board.id == activeBoardID
        let taskCount = board.tasks?.count ?? 0
        return HStack(alignment: .center, spacing: 12) {
            Text(board.iconEmoji)
                .font(.title2)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(board.title.isEmpty ? "Untitled" : board.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(deleteMode ? .red : .primary)

                HStack(spacing: 6) {
                    Text(board.subtitle.isEmpty ? "\(taskCount) tasks" : board.subtitle)
                    if !board.subtitle.isEmpty {
                        Text("·")
                        Text("\(taskCount) tasks")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if deleteMode {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.red)
            } else if isActive {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.accent)
            }
        }
        .padding(.vertical, 16)
    }

    private func beginDrag(of board: Board) -> String {
        let boardID = board.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingBoardID = boardID
        }
        return board.id.uuidString
    }

    private var deleteButton: some View {
        Button { deleteMode = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(.subheadline, weight: .bold))
                Text("Delete a Board")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addBoard() {
        let newBoard = SwiftDataManager.createBoard(
            title: String(localized: "Choose a Title"),
            subtitle: String(localized: "Choose a Subtitle"),
            into: context
        )
        onPickBoard(newBoard.id)
        dismiss()
    }

    private func deleteBoard(_ board: Board) {
        guard boards.count > 1 else { return }
        let wasActive = board.id == activeBoardID
        let fallback = boards.first(where: { $0.id != board.id })
        let tasks = board.tasks ?? []
        for task in tasks {
            NotificationService.cancel(for: task)
        }
        context.delete(board)
        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        if wasActive, let fallback {
            onPickBoard(fallback.id)
        }
    }
}

private struct BoardReorderDropDelegate: DropDelegate {
    let target: Board
    let boards: [Board]
    let context: ModelContext
    @Binding var draggingBoardID: UUID?
    @Binding var dragSessionEnded: Bool

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        guard let id = draggingBoardID, id != target.id else { return }
        applyMove(draggedID: id)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let id = draggingBoardID {
            applyMove(draggedID: id)
            try? context.save()
        }
        draggingBoardID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        return true
    }

    private func applyMove(draggedID: UUID) {
        guard draggedID != target.id else { return }
        var ordered = boards
        guard let from = ordered.firstIndex(where: { $0.id == draggedID }),
              let to = ordered.firstIndex(where: { $0.id == target.id }),
              from != to else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            let item = ordered.remove(at: from)
            ordered.insert(item, at: to)
            for (i, b) in ordered.enumerated() {
                if b.sortIndex != i {
                    b.sortIndex = i
                }
            }
        }
    }
}
