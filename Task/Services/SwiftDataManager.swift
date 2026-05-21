import Foundation
import SwiftData

enum SwiftDataManager {
    static let schema = Schema([
        Board.self,
        BoardGroup.self,
        TaskTag.self,
        TaskItem.self
    ])

    /// Set true on the launch that fell back to an in-memory store, so the next UI render
    /// can warn the user that their writes won't persist across relaunches.
    static let inMemoryFallbackKey = "task.lastLaunchInMemory"

    /// Flag flipped once we've copied the legacy global per-task-defaults UserDefaults
    /// (Default Status, Card Order, Reminder Time) into the existing first board.
    static let boardDefaultsMigratedKey = "task.boardDefaultsMigrated"

    static func makeModelContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            UserDefaults.standard.set(false, forKey: inMemoryFallbackKey)
            return container
        } catch {
            // Persistent store failed to open. Keep the app usable with an in-memory store
            // and flag the situation so RootView can surface it.
            UserDefaults.standard.set(true, forKey: inMemoryFallbackKey)
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memoryConfig])
        }
    }

    /// Title, subtitle, and icon for each board the app seeds on first launch.
    /// Listed in display order — first entry becomes the initial active board.
    static let defaultSeedBoards: [(title: String, subtitle: String, icon: String)] = [
        ("Personal", "Live a good life", "🏃"),
        ("Study", "Always learning", "🎓"),
        ("Work", "Grinding", "💼")
    ]

    @MainActor
    static func ensureSeed(context: ModelContext) {
        let descriptor = FetchDescriptor<Board>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            for spec in defaultSeedBoards {
                _ = createBoard(title: spec.title, subtitle: spec.subtitle, iconEmoji: spec.icon, into: context)
            }
        }
        migrateLegacyBoardDefaultsIfNeeded(context: context)
    }

    @MainActor
    @discardableResult
    static func createBoard(
        title: String = "TooMuchToDo",
        subtitle: String = "Work Harder Play Harder",
        iconEmoji: String = "📌",
        into context: ModelContext
    ) -> Board {
        let existing = (try? context.fetch(FetchDescriptor<Board>())) ?? []
        let nextSortIndex = (existing.map(\.sortIndex).max() ?? -1) + 1

        let board = Board(title: title, subtitle: subtitle)
        board.iconEmoji = iconEmoji
        board.sortIndex = nextSortIndex
        context.insert(board)

        let defaults: [(String, ColorKey)] = [
            ("Waiting", .blue),
            ("Doing", .red),
            ("Pending", .yellow),
            ("Done", .green),
            ("Archive", .gray)
        ]
        for (index, item) in defaults.enumerated() {
            let group = BoardGroup(name: item.0, colorKey: item.1, sortIndex: index)
            group.board = board
            context.insert(group)
        }

        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        return board
    }

    /// Copies legacy global Settings (Default Status, Card Order, Reminder Time) onto the
    /// first board exactly once. After upgrade the user keeps the preferences they had
    /// before multi-board; new boards start with fresh defaults.
    @MainActor
    private static func migrateLegacyBoardDefaultsIfNeeded(context: ModelContext) {
        let d = UserDefaults.standard
        guard !d.bool(forKey: boardDefaultsMigratedKey) else { return }
        let boards = (try? context.fetch(FetchDescriptor<Board>())) ?? []
        guard let first = boards.sorted(by: { $0.createdAt < $1.createdAt }).first else { return }

        if let legacyGroupID = d.string(forKey: "task.defaultGroupID") {
            first.defaultGroupID = legacyGroupID
        }
        let legacySortRaw = d.string(forKey: "task.cardSortField") ?? ""
        if legacySortRaw == "workingDate" || legacySortRaw == "dueDate" {
            first.cardSortFieldRaw = "date"
        } else if !legacySortRaw.isEmpty {
            first.cardSortFieldRaw = legacySortRaw
        }
        if let legacyDir = d.string(forKey: "task.cardSortDirection"), !legacyDir.isEmpty {
            first.cardSortDirectionRaw = legacyDir
        }
        if d.object(forKey: "task.reminderMinutesOfDay") != nil {
            let minutes = d.integer(forKey: "task.reminderMinutesOfDay")
            if (0..<24*60).contains(minutes) {
                first.reminderMinutesOfDay = minutes
            }
        }

        try? context.save()
        d.set(true, forKey: boardDefaultsMigratedKey)
    }
}
