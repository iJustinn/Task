import SwiftUI
import SwiftData
import UIKit

struct BoardSwitcherView: View {
    let activeBoardID: UUID
    var onPickBoard: (UUID) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Board.sortIndex) private var boards: [Board]

    @State private var pendingDelete: Board?
    @State private var draggingBoardID: UUID?
    @State private var dragSessionEnded: Bool = false
    @State private var deleteZoneHovered: Bool = false
    @State private var dragOverScreen: Bool = false
    @State private var showDeleteZone: Bool = false
    @State private var hideDeleteZoneTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var canDelete: Bool { boards.count > 1 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(boards, id: \.id) { board in
                            boardTile(board)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 120)
                }

                if showDeleteZone && canDelete {
                    deleteDropZone
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onDrop(of: StringMoveDropDelegate.acceptedTypes, isTargeted: $dragOverScreen) { _ in
                // Drop landed on the empty background — no reorder/delete delegate
                // claimed it. Clear our internal drag id and let isTargeted
                // (debounced into showDeleteZone) hide the trash zone.
                draggingBoardID = nil
                deleteZoneHovered = false
                return false
            }
            .onChange(of: dragOverScreen) { _, isOver in
                // Debounce: brief false→true flips that SwiftUI produces as the
                // drag preview crosses geometry boundaries shouldn't re-animate
                // the trash zone. Only commit to hiding after 300ms of stable
                // "not over screen", but show immediately on first entry.
                hideDeleteZoneTask?.cancel()
                if isOver {
                    showDeleteZone = true
                } else {
                    hideDeleteZoneTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if Task.isCancelled { return }
                        showDeleteZone = false
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: showDeleteZone)
            .navigationTitle("Boards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { addBoard() }
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
                }
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
    }

    private func boardTile(_ board: Board) -> some View {
        boardCardContent(board)
            .onTapGesture {
                onPickBoard(board.id)
                dismiss()
            }
            .draggable(beginDrag(of: board)) {
                boardCardContent(board)
                    .frame(maxWidth: 200)
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

    private func boardCardContent(_ board: Board) -> some View {
        let isActive = board.id == activeBoardID
        let taskCount = board.tasks?.count ?? 0
        return GridTile(
            title: board.title,
            subtitle: "\(taskCount) tasks",
            iconText: board.iconEmoji,
            tintColor: .accentColor,
            isSelected: isActive
        )
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func beginDrag(of board: Board) -> String {
        let boardID = board.id
        DispatchQueue.main.async {
            guard !dragSessionEnded else { return }
            draggingBoardID = boardID
        }
        return board.id.uuidString
    }

    private var deleteDropZone: some View {
        let baseColor = Color.red
        let tint = deleteZoneHovered ? baseColor.opacity(0.85) : baseColor.opacity(0.45)
        return HStack(spacing: 10) {
            Image(systemName: "trash.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(deleteZoneHovered ? "Release to delete" : "Drag here to delete")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(baseColor.opacity(deleteZoneHovered ? 0.95 : 0.6), lineWidth: 1.6)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .onDrop(
            of: StringMoveDropDelegate.acceptedTypes,
            delegate: BoardDeleteDropDelegate(
                draggingBoardID: $draggingBoardID,
                dragSessionEnded: $dragSessionEnded,
                hovered: $deleteZoneHovered,
                resolveBoard: { id in boards.first(where: { $0.id == id }) },
                onDelete: { board in pendingDelete = board }
            )
        )
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

private struct BoardDeleteDropDelegate: DropDelegate {
    @Binding var draggingBoardID: UUID?
    @Binding var dragSessionEnded: Bool
    @Binding var hovered: Bool
    let resolveBoard: (UUID) -> Board?
    let onDelete: (Board) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        // Guard against SwiftUI firing dropEntered repeatedly while the drag
        // is still inside — only the first entry should fire the haptic.
        guard !hovered else { return }
        hovered = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func dropExited(info: DropInfo) {
        hovered = false
    }

    func performDrop(info: DropInfo) -> Bool {
        let draggedID = draggingBoardID
        hovered = false
        draggingBoardID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        if let id = draggedID, let board = resolveBoard(id) {
            DispatchQueue.main.async {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                onDelete(board)
            }
            return true
        }
        return false
    }
}
