import Foundation
import SwiftData

@Model
final class Board {
    var id: UUID = UUID()
    var title: String = "TooMuchToDo"
    var subtitle: String = "Work Harder Play Harder"
    var iconEmoji: String = "📌"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

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
}
