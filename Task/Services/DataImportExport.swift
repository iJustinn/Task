import Foundation
import SwiftData

/// v2 wire format. Backward-compat with v1 single-board exports — see `decodePayload`.
struct MultiBoardExportPayload: Codable {
    var version: Int = 2
    var exportedAt: Date = Date()
    var boards: [BoardExportEntry]
}

struct BoardExportEntry: Codable {
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
    var sortIndex: Int?
    var defaultGroupID: String?
    var cardSortFieldRaw: String?
    var cardSortDirectionRaw: String?
    var reminderMinutesOfDay: Int?
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
    var repeatRule: String?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
    var groupID: UUID?
    var tagIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case id, title, notes, workingStart, workingEnd, dueDate, hasReminder
        case repeatRule, sortIndex, createdAt, updatedAt, groupID, tagIDs
    }

    init(
        id: UUID,
        title: String,
        notes: String,
        workingStart: Date?,
        workingEnd: Date?,
        dueDate: Date?,
        hasReminder: Bool,
        repeatRule: String?,
        sortIndex: Int,
        createdAt: Date,
        updatedAt: Date,
        groupID: UUID?,
        tagIDs: [UUID]
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.workingStart = workingStart
        self.workingEnd = workingEnd
        self.dueDate = dueDate
        self.hasReminder = hasReminder
        self.repeatRule = repeatRule
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.groupID = groupID
        self.tagIDs = tagIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decode(String.self, forKey: .notes)
        workingStart = try c.decodeIfPresent(Date.self, forKey: .workingStart)
        workingEnd = try c.decodeIfPresent(Date.self, forKey: .workingEnd)
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        hasReminder = try c.decode(Bool.self, forKey: .hasReminder)
        repeatRule = try c.decodeIfPresent(String.self, forKey: .repeatRule)
        sortIndex = try c.decode(Int.self, forKey: .sortIndex)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        groupID = try c.decodeIfPresent(UUID.self, forKey: .groupID)
        tagIDs = try c.decode([UUID].self, forKey: .tagIDs)
    }
}

/// Legacy v1 wire format. Read-only — never emitted by current code.
private struct LegacySingleBoardPayload: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var board: BoardExport
    var groups: [GroupExport]
    var tags: [TagExport]
    var tasks: [TaskExport]
}

struct ImportResult {
    var success: Bool
    var boardCount: Int = 0
    var taskCount: Int = 0
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
        guard !boards.isEmpty else { return nil }

        let sortedBoards = boards.sorted { $0.sortIndex < $1.sortIndex }
        let entries = sortedBoards.map { board -> BoardExportEntry in
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
                    repeatRule: task.repeatRuleRaw.isEmpty ? nil : task.repeatRuleRaw,
                    sortIndex: task.sortIndex,
                    createdAt: task.createdAt,
                    updatedAt: task.updatedAt,
                    groupID: task.group?.id,
                    tagIDs: (task.tags ?? []).map(\.id)
                )
            }
            return BoardExportEntry(
                board: BoardExport(
                    id: board.id,
                    title: board.title,
                    subtitle: board.subtitle,
                    iconEmoji: board.iconEmoji,
                    sortIndex: board.sortIndex,
                    defaultGroupID: board.defaultGroupID,
                    cardSortFieldRaw: board.cardSortFieldRaw,
                    cardSortDirectionRaw: board.cardSortDirectionRaw,
                    reminderMinutesOfDay: board.reminderMinutesOfDay,
                    createdAt: board.createdAt,
                    updatedAt: board.updatedAt
                ),
                groups: groups,
                tags: tags,
                tasks: tasks
            )
        }

        let payload = MultiBoardExportPayload(boards: entries)
        return try? makeEncoder().encode(payload)
    }

    private static func decodePayload(_ data: Data) -> MultiBoardExportPayload? {
        let decoder = makeDecoder()
        if let multi = try? decoder.decode(MultiBoardExportPayload.self, from: data), !multi.boards.isEmpty {
            return multi
        }
        if let legacy = try? decoder.decode(LegacySingleBoardPayload.self, from: data) {
            return MultiBoardExportPayload(
                version: 2,
                exportedAt: legacy.exportedAt,
                boards: [BoardExportEntry(
                    board: legacy.board,
                    groups: legacy.groups,
                    tags: legacy.tags,
                    tasks: legacy.tasks
                )]
            )
        }
        return nil
    }

    @MainActor
    @discardableResult
    static func importData(_ data: Data, context: ModelContext) async -> ImportResult {
        guard let payload = decodePayload(data) else {
            return .failure
        }

        var orphanTasks = 0
        var orphanTagRefs = 0
        var taskCount = 0
        var processed = 0
        // Collect notification mutations from every board merge; replay them only
        // after the final save commits. If the save fails we drop the plan, so
        // cancelled reminders don't disappear and imported reminders aren't scheduled
        // for tasks that never made it to disk.
        var plan = NotificationPlan()

        for entry in payload.boards {
            let (oTasks, oTagRefs) = await mergeBoard(entry, into: context, plan: &plan)
            orphanTasks += oTasks
            orphanTagRefs += oTagRefs
            taskCount += entry.tasks.count
            processed += entry.tasks.count
            if processed % 50 >= 49 {
                await Task.yield()
            }
        }

        do {
            try context.save()
        } catch {
            // Surface the failure instead of returning success with unsaved state. The
            // caller's failure alert is more useful than a misleading "imported".
            return .failure
        }
        plan.apply()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        return ImportResult(
            success: true,
            boardCount: payload.boards.count,
            taskCount: taskCount,
            orphanTasks: orphanTasks,
            orphanTagRefs: orphanTagRefs
        )
    }

    /// Notification side effects queued during a `mergeBoard` pass. Replayed by
    /// `apply()` only after the final import save commits, so a failed save can't
    /// leave the user with cancelled-but-not-replaced reminders.
    private struct NotificationPlan {
        var cancellations: [TaskItem] = []
        var scheduleAfterSave: [TaskItem] = []

        mutating func cancel(_ task: TaskItem) {
            cancellations.append(task)
        }

        mutating func schedule(_ task: TaskItem) {
            scheduleAfterSave.append(task)
        }

        func apply() {
            for t in cancellations { NotificationService.cancel(for: t) }
            for t in scheduleAfterSave where t.hasReminder { NotificationService.schedule(for: t) }
        }
    }

    @MainActor
    private static func mergeBoard(_ entry: BoardExportEntry, into context: ModelContext, plan: inout NotificationPlan) async -> (orphanTasks: Int, orphanTagRefs: Int) {
        let payloadBoard = entry.board
        let allBoards = (try? context.fetch(FetchDescriptor<Board>())) ?? []

        let board: Board
        if let existing = allBoards.first(where: { $0.id == payloadBoard.id }) {
            existing.title = payloadBoard.title
            existing.subtitle = payloadBoard.subtitle
            if let icon = payloadBoard.iconEmoji { existing.iconEmoji = icon }
            if let s = payloadBoard.sortIndex { existing.sortIndex = s }
            if let gid = payloadBoard.defaultGroupID { existing.defaultGroupID = gid }
            if let sf = payloadBoard.cardSortFieldRaw { existing.cardSortFieldRaw = sf }
            if let sd = payloadBoard.cardSortDirectionRaw { existing.cardSortDirectionRaw = sd }
            if let m = payloadBoard.reminderMinutesOfDay { existing.reminderMinutesOfDay = m }
            existing.updatedAt = payloadBoard.updatedAt
            board = existing
        } else {
            let newBoard = Board(title: payloadBoard.title, subtitle: payloadBoard.subtitle)
            newBoard.id = payloadBoard.id
            if let icon = payloadBoard.iconEmoji { newBoard.iconEmoji = icon }
            newBoard.sortIndex = payloadBoard.sortIndex ?? ((allBoards.map(\.sortIndex).max() ?? -1) + 1)
            if let gid = payloadBoard.defaultGroupID { newBoard.defaultGroupID = gid }
            if let sf = payloadBoard.cardSortFieldRaw { newBoard.cardSortFieldRaw = sf }
            if let sd = payloadBoard.cardSortDirectionRaw { newBoard.cardSortDirectionRaw = sd }
            if let m = payloadBoard.reminderMinutesOfDay { newBoard.reminderMinutesOfDay = m }
            newBoard.createdAt = payloadBoard.createdAt
            newBoard.updatedAt = payloadBoard.updatedAt
            context.insert(newBoard)
            board = newBoard
        }

        // Existing groups/tags scoped to *this* board. Cross-board name matches are
        // ignored on purpose — two boards may share a group called "Doing".
        // Build the name-lookups with first-wins loops so duplicate case-folded names
        // (legitimately possible after past imports or hand-edited JSON) don't trap
        // Dictionary(uniqueKeysWithValues:).
        let existingGroups = (board.groups ?? [])
        var groupsByID: [UUID: BoardGroup] = [:]
        var groupsByName: [String: BoardGroup] = [:]
        for g in existingGroups {
            groupsByID[g.id] = g
            let key = g.name.lowercased()
            if groupsByName[key] == nil { groupsByName[key] = g }
        }
        for g in entry.groups {
            if let existing = groupsByID[g.id] {
                existing.name = g.name
                existing.colorKeyRaw = g.colorKey
                existing.sortIndex = g.sortIndex
                existing.board = board
                groupsByName[g.name.lowercased()] = existing
            } else if let existing = groupsByName[g.name.lowercased()] {
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

        let existingTags = (board.tags ?? [])
        var tagsByID: [UUID: TaskTag] = [:]
        var tagsByName: [String: TaskTag] = [:]
        for t in existingTags {
            tagsByID[t.id] = t
            let key = t.name.lowercased()
            if tagsByName[key] == nil { tagsByName[key] = t }
        }
        for t in entry.tags {
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

        let fallbackGroup = board.orderedGroups.first
        let existingTasks = (board.tasks ?? [])
        var tasksByID: [UUID: TaskItem] = Dictionary(uniqueKeysWithValues: existingTasks.map { ($0.id, $0) })
        var orphanTasks = 0
        var orphanTagRefs = 0
        for (idx, t) in entry.tasks.enumerated() {
            let resolvedTags = t.tagIDs.compactMap { tagsByID[$0] }
            orphanTagRefs += (t.tagIDs.count - resolvedTags.count)

            // A task without a group can't be rendered on the board (BoardView only
            // iterates `board.orderedGroups`), so route both "unknown groupID" and
            // "no groupID" through the fallback. Without this, the task is silently
            // hidden after import.
            let resolvedGroup: BoardGroup?
            if let gid = t.groupID, let match = groupsByID[gid] {
                resolvedGroup = match
            } else {
                orphanTasks += 1
                resolvedGroup = fallbackGroup
            }

            let task: TaskItem
            if let existing = tasksByID[t.id] {
                plan.cancel(existing)
                existing.title = t.title
                existing.notes = t.notes
                existing.workingStart = t.workingStart
                existing.workingEnd = t.workingEnd
                existing.dueDate = t.dueDate
                existing.hasReminder = t.hasReminder
                existing.repeatRuleRaw = t.repeatRule ?? ""
                existing.sortIndex = t.sortIndex
                existing.updatedAt = t.updatedAt
                existing.board = board
                existing.group = resolvedGroup
                existing.tags = resolvedTags
                task = existing
            } else {
                let new = TaskItem(title: t.title, notes: t.notes, sortIndex: t.sortIndex)
                new.id = t.id
                new.workingStart = t.workingStart
                new.workingEnd = t.workingEnd
                new.dueDate = t.dueDate
                new.hasReminder = t.hasReminder
                new.repeatRuleRaw = t.repeatRule ?? ""
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
                plan.schedule(task)
            }
            if idx % 50 == 49 {
                await Task.yield()
            }
        }

        return (orphanTasks, orphanTagRefs)
    }

    /// `true` when the destructive delete saved cleanly and the re-seed completed.
    /// `false` means the user's data is in an indeterminate state and the caller
    /// should show a failure alert instead of pretending the reset succeeded.
    @MainActor
    @discardableResult
    static func resetAll(context: ModelContext) async -> Bool {
        let existingTasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let plannedCancellations = existingTasks
        for board in (try? context.fetch(FetchDescriptor<Board>())) ?? [] {
            context.delete(board)
        }
        // Save the destructive deletion first so we can bail out cleanly if it fails,
        // before we cancel real notifications or wipe UserDefaults.
        do {
            try context.save()
        } catch {
            return false
        }
        for (idx, task) in plannedCancellations.enumerated() {
            NotificationService.cancel(for: task)
            if idx % 50 == 49 {
                await Task.yield()
            }
        }
        UserDefaults.standard.removeObject(forKey: "task.activeBoardID")

        // If we're running in the in-memory fallback, the corrupt SQLite file on
        // disk is still there and would re-trap us into fallback on the next launch.
        // Wipe it now so the next `makeModelContainer()` can rebuild cleanly.
        if UserDefaults.standard.bool(forKey: SwiftDataManager.inMemoryFallbackKey) {
            SwiftDataManager.purgePersistentStoreFiles()
        }

        SwiftDataManager.ensureSeed(context: context)
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        return true
    }

    static func defaultExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "task-export-\(formatter.string(from: Date()))"
    }
}
