import Foundation
import SwiftData

enum SwiftDataManager {
    static let schema = Schema([
        Board.self,
        BoardGroup.self,
        TaskTag.self,
        TaskItem.self
    ])

    static func makeModelContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Fall back to an in-memory store if the persistent store can't be opened.
            // This keeps the app usable rather than crashing on schema/migration failures.
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
