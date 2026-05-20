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

    @MainActor
    static func ensureSeed(context: ModelContext) {
        let descriptor = FetchDescriptor<Board>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            seedDefaultBoard(into: context)
        }
    }

    @MainActor
    private static func seedDefaultBoard(into context: ModelContext) {
        let board = Board()
        context.insert(board)

        let defaults: [(String, ColorKey)] = [
            ("Daily", .purple),
            ("Weekly", .purple),
            ("Waiting", .blue),
            ("Doing", .red),
            ("Pending", .yellow),
            ("Done", .green)
        ]
        for (index, item) in defaults.enumerated() {
            let group = BoardGroup(name: item.0, colorKey: item.1, sortIndex: index)
            group.board = board
            context.insert(group)
        }

        try? context.save()
    }
}
