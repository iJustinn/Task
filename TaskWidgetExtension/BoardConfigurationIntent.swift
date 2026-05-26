import AppIntents
import WidgetKit

enum WidgetBackgroundStyle: String, AppEnum {
    case systemDefault
    case pureBlack
    case pureWhite

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Background"
    static var caseDisplayRepresentations: [WidgetBackgroundStyle: DisplayRepresentation] = [
        .systemDefault: "Default",
        .pureBlack: "Black",
        .pureWhite: "White"
    ]
}

struct BoardEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Board"

    static var defaultQuery = BoardEntityQuery()

    var id: UUID
    var title: String
    var iconEmoji: String

    var displayRepresentation: DisplayRepresentation {
        let resolvedTitle = title.isEmpty ? String(localized: "Untitled") : title
        return DisplayRepresentation(title: "\(iconEmoji) \(resolvedTitle)")
    }
}

struct BoardEntityQuery: EntityQuery {
    func entities(for identifiers: [BoardEntity.ID]) async throws -> [BoardEntity] {
        let all = WidgetSharedDefaults.readBoardList()
        let set = Set(identifiers)
        return all
            .filter { set.contains($0.id) }
            .map { BoardEntity(id: $0.id, title: $0.title, iconEmoji: $0.iconEmoji) }
    }

    func suggestedEntities() async throws -> [BoardEntity] {
        WidgetSharedDefaults.readBoardList()
            .map { BoardEntity(id: $0.id, title: $0.title, iconEmoji: $0.iconEmoji) }
    }
}

struct StatusEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Status"

    static var defaultQuery = StatusEntityQuery()

    var id: UUID
    var boardID: UUID
    var boardEmoji: String
    var boardTitle: String
    var name: String
    var colorKey: String
    var sortIndex: Int

    var displayRepresentation: DisplayRepresentation {
        let resolvedName = name.isEmpty ? String(localized: "Untitled") : name
        let resolvedBoard = boardTitle.isEmpty ? String(localized: "Untitled") : boardTitle
        return DisplayRepresentation(title: "\(boardEmoji) \(resolvedName)", subtitle: "\(resolvedBoard)")
    }
}

struct StatusEntityQuery: EntityQuery {
    func entities(for identifiers: [StatusEntity.ID]) async throws -> [StatusEntity] {
        let all = WidgetSharedDefaults.readStatusList()
        let set = Set(identifiers)
        return all
            .filter { set.contains($0.id) }
            .map(Self.entity)
    }

    func suggestedEntities() async throws -> [StatusEntity] {
        WidgetSharedDefaults.readStatusList().map(Self.entity)
    }

    private static func entity(from entry: WidgetStatusListEntry) -> StatusEntity {
        StatusEntity(
            id: entry.id,
            boardID: entry.boardID,
            boardEmoji: entry.boardEmoji,
            boardTitle: entry.boardTitle,
            name: entry.name,
            colorKey: entry.colorKey,
            sortIndex: entry.sortIndex
        )
    }
}

struct BoardConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Board and Status"
    static var description = IntentDescription("Pick which board and status the widget shows. Leave empty to see tasks from every board or status.")

    @Parameter(title: "Board")
    var board: BoardEntity?

    @Parameter(title: "Status")
    var status: StatusEntity?

    @Parameter(title: "Background")
    var background: WidgetBackgroundStyle?

    init() {
        background = .systemDefault
    }

    init(
        board: BoardEntity?,
        status: StatusEntity? = nil,
        background: WidgetBackgroundStyle = .systemDefault
    ) {
        self.board = board
        self.status = status
        self.background = background
    }
}
