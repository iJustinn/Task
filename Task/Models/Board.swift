import Foundation
import SwiftData

@Model
final class Board {
    var id: UUID = UUID()
    var title: String = "TooMuchToDo"
    var subtitle: String = "Work Harder Play Harder"
    var iconEmoji: String = "📌"
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var defaultGroupID: String? = nil
    var cardSortFieldRaw: String = "manual"
    var cardSortDirectionRaw: String = "ascending"
    var reminderMinutesOfDay: Int = 540

    @Relationship(deleteRule: .cascade, inverse: \BoardGroup.board)
    var groups: [BoardGroup]? = []

    @Relationship(deleteRule: .cascade, inverse: \TaskTag.board)
    var tags: [TaskTag]? = []

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.board)
    var tasks: [TaskItem]? = []

    init(title: String = "TooMuchToDo", subtitle: String = "Work Harder Play Harder") {
        self.title = title
        self.subtitle = subtitle
    }

    var orderedGroups: [BoardGroup] {
        (groups ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var orderedTags: [TaskTag] {
        (tags ?? []).sorted {
            if $0.sortIndex != $1.sortIndex {
                return $0.sortIndex < $1.sortIndex
            }
            return $0.createdAt < $1.createdAt
        }
    }

    var defaultGroup: BoardGroup? {
        let all = orderedGroups
        if let id = defaultGroupID,
           let match = all.first(where: { $0.id.uuidString == id }) {
            return match
        }
        return all.first
    }

    var cardSortField: CardSortField {
        get { CardSortField(rawValue: cardSortFieldRaw) ?? .manual }
        set { cardSortFieldRaw = newValue.rawValue }
    }

    var cardSortDirection: CardSortDirection {
        get { CardSortDirection(rawValue: cardSortDirectionRaw) ?? .ascending }
        set { cardSortDirectionRaw = newValue.rawValue }
    }
}
