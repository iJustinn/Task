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
    /// Pre-drag `sortIndex` snapshot — captured on first hover, restored if the
    /// user cancels the drag (releases outside any row, dismisses the sheet, or
    /// goes idle for 5 s) so dirty model mutations don't leak into the next save.
    @State private var preDragSortIndex: [UUID: Int] = [:]
    @State private var reorderWatchdog: Task<Void, Never>?

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
        .onDisappear {
            // Sheet dismissed mid-drag: roll back any uncommitted reorder so the
            // dirty `sortIndex` doesn't ride along with the next unrelated save.
            if !preDragSortIndex.isEmpty {
                rollbackReorderIfPending()
            }
            reorderWatchdog?.cancel()
            reorderWatchdog = nil
        }
    }

    // MARK: - Reorder rollback

    private func captureReorderSnapshotIfNeeded() {
        guard preDragSortIndex.isEmpty else { return }
        var snap: [UUID: Int] = [:]
        for board in boards { snap[board.id] = board.sortIndex }
        preDragSortIndex = snap
        armReorderWatchdog()
    }

    private func rearmReorderWatchdogIfDragging() {
        guard !preDragSortIndex.isEmpty else { return }
        armReorderWatchdog()
    }

    private func armReorderWatchdog() {
        reorderWatchdog?.cancel()
        reorderWatchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if Task.isCancelled { return }
            rollbackReorderIfPending()
        }
    }

    private func completeReorder() {
        reorderWatchdog?.cancel()
        reorderWatchdog = nil
        preDragSortIndex.removeAll()
    }

    private func rollbackReorderIfPending() {
        guard !preDragSortIndex.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            for board in boards {
                if let original = preDragSortIndex[board.id], board.sortIndex != original {
                    board.sortIndex = original
                }
            }
        }
        try? context.save()
        preDragSortIndex.removeAll()
        reorderWatchdog?.cancel()
        reorderWatchdog = nil
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
                delegate: ReorderDropDelegate<Board>(
                    target: board,
                    ordered: { boards },
                    onCommit: { try? context.save() },
                    onBeginDrag: { captureReorderSnapshotIfNeeded() },
                    onTick: { rearmReorderWatchdogIfDragging() },
                    onCompleteDrag: { completeReorder() },
                    draggingID: $draggingBoardID,
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
                Text(board.title.isEmpty ? String(localized: "Untitled") : board.title)
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
            SheetActionButtonLabel(title: "Delete a Board", systemName: "trash", tintColor: .red, fillsWidth: true)
        }
        .buttonStyle(.plain)
    }

    private func addBoard() {
        // Empty title/subtitle so the board header's TextField shows its prompt
        // hint instead of pre-filling text the user has to delete by hand.
        let newBoard = SwiftDataManager.createBoard(
            title: "",
            subtitle: "",
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
