import Foundation
import SwiftData

struct BoardExportPayload: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var board: BoardExport
    var groups: [GroupExport]
    var tags: [TagExport]
    var tasks: [TaskExport]
}

struct BoardExport: Codable {
    var id: UUID
    var title: String
    var subtitle: String
    var iconEmoji: String?
    var createdAt: Date
    var updatedAt: Date
}

struct GroupExport: Codable {
    var id: UUID
    var name: String
    var colorKey: String
    var sortIndex: Int
    var createdAt: Date
}

struct TagExport: Codable {
    var id: UUID
    var name: String
    var colorKey: String
    var sortIndex: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, colorKey, sortIndex, createdAt
    }

    init(id: UUID, name: String, colorKey: String, sortIndex: Int, createdAt: Date) {
        self.id = id
        self.name = name
        self.colorKey = colorKey
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorKey = try c.decode(String.self, forKey: .colorKey)
        sortIndex = try c.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}

struct TaskExport: Codable {
    var id: UUID
    var title: String
    var notes: String
    var workingStart: Date?
    var workingEnd: Date?
    var dueDate: Date?
    var hasReminder: Bool
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
    var groupID: UUID?
    var tagIDs: [UUID]
}

struct ImportResult {
    var success: Bool
    var orphanTasks: Int = 0
    var orphanTagRefs: Int = 0

    static let failure = ImportResult(success: false)
}

enum DataImportExport {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @MainActor
    static func exportData(context: ModelContext) -> Data? {
        let boards = (try? context.fetch(FetchDescriptor<Board>())) ?? []
        guard let board = boards.first else { return nil }

        let groups: [GroupExport] = board.orderedGroups.map { g in
            GroupExport(id: g.id, name: g.name, colorKey: g.colorKeyRaw, sortIndex: g.sortIndex, createdAt: g.createdAt)
        }
        let tags: [TagExport] = board.orderedTags.map { t in
            TagExport(id: t.id, name: t.name, colorKey: t.colorKeyRaw, sortIndex: t.sortIndex, createdAt: t.createdAt)
        }
        let tasks: [TaskExport] = (board.tasks ?? []).map { task in
            TaskExport(
                id: task.id,
                title: task.title,
                notes: task.notes,
                workingStart: task.workingStart,
                workingEnd: task.workingEnd,
                dueDate: task.dueDate,
                hasReminder: task.hasReminder,
                sortIndex: task.sortIndex,
                createdAt: task.createdAt,
                updatedAt: task.updatedAt,
                groupID: task.group?.id,
                tagIDs: (task.tags ?? []).map(\.id)
            )
        }

        let payload = BoardExportPayload(
            board: BoardExport(
                id: board.id,
                title: board.title,
                subtitle: board.subtitle,
                iconEmoji: board.iconEmoji,
                createdAt: board.createdAt,
                updatedAt: board.updatedAt
            ),
            groups: groups,
            tags: tags,
            tasks: tasks
        )

        return try? makeEncoder().encode(payload)
    }

    @MainActor
    @discardableResult
    static func importData(_ data: Data, context: ModelContext) async -> ImportResult {
        guard let payload = try? makeDecoder().decode(BoardExportPayload.self, from: data) else {
            return .failure
        }

        // Resolve target board: prefer same-ID match, else reuse the existing singleton, else create.
        let allBoards = (try? context.fetch(FetchDescriptor<Board>())) ?? []
        let board: Board
        if let existing = allBoards.first(where: { $0.id == payload.board.id }) {
            existing.title = payload.board.title
            existing.subtitle = payload.board.subtitle
            if let icon = payload.board.iconEmoji { existing.iconEmoji = icon }
            existing.updatedAt = payload.board.updatedAt
            board = existing
        } else if let existing = allBoards.first {
            existing.title = payload.board.title
            existing.subtitle = payload.board.subtitle
            if let icon = payload.board.iconEmoji { existing.iconEmoji = icon }
            existing.updatedAt = payload.board.updatedAt
            board = existing
        } else {
            let newBoard = Board(title: payload.board.title, subtitle: payload.board.subtitle)
            newBoard.id = payload.board.id
            if let icon = payload.board.iconEmoji { newBoard.iconEmoji = icon }
            newBoard.createdAt = payload.board.createdAt
            newBoard.updatedAt = payload.board.updatedAt
            context.insert(newBoard)
            board = newBoard
        }

        // Merge groups: prefer ID match, then name match (case-insensitive), else insert.
        let existingGroups = (try? context.fetch(FetchDescriptor<BoardGroup>())) ?? []
        var groupsByID: [UUID: BoardGroup] = Dictionary(uniqueKeysWithValues: existingGroups.map { ($0.id, $0) })
        var groupsByName: [String: BoardGroup] = Dictionary(uniqueKeysWithValues:
            existingGroups.map { ($0.name.lowercased(), $0) }
        )
        for g in payload.groups {
            if let existing = groupsByID[g.id] {
                existing.name = g.name
                existing.colorKeyRaw = g.colorKey
                existing.sortIndex = g.sortIndex
                existing.board = board
                groupsByName[g.name.lowercased()] = existing
            } else if let existing = groupsByName[g.name.lowercased()] {
                // Same-name match — collapse the imported group into the existing one.
                existing.colorKeyRaw = g.colorKey
                existing.sortIndex = g.sortIndex
                existing.board = board
                groupsByID[g.id] = existing
            } else {
                let group = BoardGroup(
                    name: g.name,
                    colorKey: ColorKey(rawValue: g.colorKey) ?? .purple,
                    sortIndex: g.sortIndex
                )
                group.id = g.id
                group.createdAt = g.createdAt
                group.board = board
                context.insert(group)
                groupsByID[g.id] = group
                groupsByName[g.name.lowercased()] = group
            }
        }

        // Merge tags: prefer ID match, then name match (case-insensitive), else insert.
        let existingTags = (try? context.fetch(FetchDescriptor<TaskTag>())) ?? []
        var tagsByID: [UUID: TaskTag] = Dictionary(uniqueKeysWithValues: existingTags.map { ($0.id, $0) })
        var tagsByName: [String: TaskTag] = Dictionary(uniqueKeysWithValues:
            existingTags.map { ($0.name.lowercased(), $0) }
        )
        for t in payload.tags {
            if let existing = tagsByID[t.id] {
                existing.name = t.name
                existing.colorKeyRaw = t.colorKey
                existing.sortIndex = t.sortIndex
                existing.board = board
                tagsByName[t.name.lowercased()] = existing
            } else if let existing = tagsByName[t.name.lowercased()] {
                existing.colorKeyRaw = t.colorKey
                existing.sortIndex = t.sortIndex
                existing.board = board
                tagsByID[t.id] = existing
            } else {
                let tag = TaskTag(
                    name: t.name,
                    colorKey: ColorKey(rawValue: t.colorKey) ?? .gray,
                    sortIndex: t.sortIndex
                )
                tag.id = t.id
                tag.createdAt = t.createdAt
                tag.board = board
                context.insert(tag)
                tagsByID[t.id] = tag
                tagsByName[t.name.lowercased()] = tag
            }
        }

        // Merge tasks by ID. Orphan groupID falls back to the first known group so the
        // task stays visible; orphan tagIDs are dropped and counted for the result alert.
        let fallbackGroup = board.orderedGroups.first
        let existingTasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        var tasksByID: [UUID: TaskItem] = Dictionary(uniqueKeysWithValues: existingTasks.map { ($0.id, $0) })
        var orphanTasks = 0
        var orphanTagRefs = 0
        for (idx, t) in payload.tasks.enumerated() {
            let resolvedTags = t.tagIDs.compactMap { tagsByID[$0] }
            orphanTagRefs += (t.tagIDs.count - resolvedTags.count)

            let resolvedGroup: BoardGroup?
            if let gid = t.groupID {
                if let match = groupsByID[gid] {
                    resolvedGroup = match
                } else {
                    orphanTasks += 1
                    resolvedGroup = fallbackGroup
                }
            } else {
                resolvedGroup = nil
            }

            let task: TaskItem
            if let existing = tasksByID[t.id] {
                NotificationService.cancel(for: existing)
                existing.title = t.title
                existing.notes = t.notes
                existing.workingStart = t.workingStart
                existing.workingEnd = t.workingEnd
                existing.dueDate = t.dueDate
                existing.hasReminder = t.hasReminder
                existing.sortIndex = t.sortIndex
                existing.updatedAt = t.updatedAt
                existing.board = board
                if t.groupID != nil { existing.group = resolvedGroup }
                existing.tags = resolvedTags
                task = existing
            } else {
                let new = TaskItem(title: t.title, notes: t.notes, sortIndex: t.sortIndex)
                new.id = t.id
                new.workingStart = t.workingStart
                new.workingEnd = t.workingEnd
                new.dueDate = t.dueDate
                new.hasReminder = t.hasReminder
                new.createdAt = t.createdAt
                new.updatedAt = t.updatedAt
                new.board = board
                new.group = resolvedGroup
                new.tags = resolvedTags
                context.insert(new)
                tasksByID[t.id] = new
                task = new
            }
            if task.hasReminder {
                NotificationService.schedule(for: task)
            }
            // Yield every 50 tasks so the import progress overlay can repaint on
            // multi-thousand-task imports without freezing the UI.
            if idx % 50 == 49 {
                await Task.yield()
            }
        }

        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        return ImportResult(success: true, orphanTasks: orphanTasks, orphanTagRefs: orphanTagRefs)
    }

    @MainActor
    static func resetAll(context: ModelContext) async {
        let existingTasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        for (idx, task) in existingTasks.enumerated() {
            NotificationService.cancel(for: task)
            if idx % 50 == 49 {
                await Task.yield()
            }
        }
        for board in (try? context.fetch(FetchDescriptor<Board>())) ?? [] {
            context.delete(board)
        }
        try? context.save()
        SwiftDataManager.ensureSeed(context: context)
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
    }

    static func defaultExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "task-export-\(formatter.string(from: Date()))"
    }
}
