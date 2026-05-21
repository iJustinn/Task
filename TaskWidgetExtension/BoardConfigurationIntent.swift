import AppIntents
import WidgetKit

struct BoardEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Board"

    static var defaultQuery = BoardEntityQuery()

    var id: UUID
    var title: String
    var iconEmoji: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(iconEmoji) \(title)")
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

struct BoardConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Board"
    static var description = IntentDescription("Pick which board's upcoming tasks the widget shows. Leave empty to see tasks from every board.")

    @Parameter(title: "Board")
    var board: BoardEntity?

    init() {}

    init(board: BoardEntity?) {
        self.board = board
    }
}
