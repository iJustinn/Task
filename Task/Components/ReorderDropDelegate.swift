import SwiftUI

/// Items that support drag-reorder share a UUID identifier and a `sortIndex` field
/// the reorder delegate renumbers on every move.
protocol Reorderable: AnyObject, Identifiable where ID == UUID {
    var sortIndex: Int { get set }
}

extension Board: Reorderable {}
extension BoardGroup: Reorderable {}
extension TaskTag: Reorderable {}

/// Shared drag-reorder `DropDelegate` for any `Reorderable`. Three near-identical
/// per-sheet delegates (BoardSwitcher / StatusPicker / TagPicker) previously
/// duplicated this logic — see `LessonsLearned.md` for the original drag-and-drop
/// notes.
///
/// Callers wire the three rollback hooks through to a `@State preDragSortIndex` +
/// `@State reorderWatchdog: Task<Void, Never>?` pair on the parent sheet (mirrors
/// `BoardView`'s task-card rollback). The hooks default to no-ops for callers that
/// don't need rollback yet — but every picker sheet should pass them, or a
/// cancelled drag will leave dirty `sortIndex` mutations in the SwiftData context.
struct ReorderDropDelegate<Item: Reorderable>: DropDelegate {
    let target: Item
    let ordered: () -> [Item]
    let onCommit: () -> Void
    /// First `dropEntered` of a drag session — capture every item's `sortIndex`
    /// into the parent sheet's snapshot and arm its rollback watchdog.
    var onBeginDrag: () -> Void = {}
    /// `dropUpdated` fires continuously while hovering. Re-arm the parent's
    /// watchdog so a slow hover doesn't trigger a mid-drag rollback. Mirrors the
    /// task-card watchdog tick added in `BoardView.rearmDragWatchdogIfDragging`.
    var onTick: () -> Void = {}
    /// `performDrop` succeeded — clear the snapshot + cancel the watchdog.
    var onCompleteDrag: () -> Void = {}
    @Binding var draggingID: UUID?
    @Binding var dragSessionEnded: Bool

    func dropUpdated(info: DropInfo) -> DropProposal? {
        onTick()
        return DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        onBeginDrag()
        guard let id = draggingID, id != target.id else { return }
        applyMove(draggedID: id)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let id = draggingID {
            applyMove(draggedID: id)
            onCommit()
        }
        onCompleteDrag()
        draggingID = nil
        dragSessionEnded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dragSessionEnded = false
        }
        return true
    }

    private func applyMove(draggedID: UUID) {
        guard draggedID != target.id else { return }
        var current = ordered()
        guard let from = current.firstIndex(where: { $0.id == draggedID }),
              let to = current.firstIndex(where: { $0.id == target.id }),
              from != to else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            let item = current.remove(at: from)
            current.insert(item, at: to)
            for (i, x) in current.enumerated() {
                if x.sortIndex != i {
                    x.sortIndex = i
                }
            }
        }
    }
}
