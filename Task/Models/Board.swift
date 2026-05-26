import Foundation
import SwiftData

@Model
final class Board {
    var id: UUID = UUID()
    var title: String = ""
    var subtitle: String = ""
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

    init(title: String, subtitle: String = "") {
        self.title = title
        self.subtitle = subtitle
    }

    var orderedGroups: [BoardGroup] {
        (groups ?? []).sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var orderedTags: [TaskTag] {
        (tags ?? []).sorted {
            if $0.sortIndex != $1.sortIndex {
                return $0.sortIndex < $1.sortIndex
            }
            return $0.createdAt < $1.createdAt
        }
    }

    /// Type-safe view over the stringly-typed `defaultGroupID` column. Stored as a
    /// String for backward compatibility with on-disk data; callers should prefer
    /// this accessor.
    var defaultGroupUUID: UUID? {
        get { defaultGroupID.flatMap(UUID.init(uuidString:)) }
        set { defaultGroupID = newValue?.uuidString }
    }

    var defaultGroup: BoardGroup? {
        let all = orderedGroups
        if let id = defaultGroupUUID,
           let match = all.first(where: { $0.id == id }) {
            return match
        }
        return all.first
    }

    func setDefaultGroup(_ group: BoardGroup, enabled: Bool) {
        if enabled {
            defaultGroupUUID = group.id
        } else if defaultGroup?.id == group.id {
            defaultGroupUUID = orderedGroups.first { $0.id != group.id }?.id
        }
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
