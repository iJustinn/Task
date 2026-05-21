import Foundation
import SwiftData

@Model
final class BoardGroup {
    var id: UUID = UUID()
    var name: String = ""
    var colorKeyRaw: String = ColorKey.purple.rawValue
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    var board: Board?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.group)
    var tasks: [TaskItem]? = []

    init(name: String, colorKey: ColorKey = .purple, sortIndex: Int = 0) {
        self.name = name
        self.colorKeyRaw = colorKey.rawValue
        self.sortIndex = sortIndex
    }

    var colorKey: ColorKey {
        get { ColorKey(rawValue: colorKeyRaw) ?? .purple }
        set { colorKeyRaw = newValue.rawValue }
    }

    var orderedTasks: [TaskItem] {
        (tasks ?? []).sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func sortedTasks(field: CardSortField, direction: CardSortDirection) -> [TaskItem] {
        let all = tasks ?? []
        let base: [TaskItem]
        switch field {
        case .manual:
            base = all.sorted { $0.sortIndex < $1.sortIndex }
            return direction == .ascending ? base : base.reversed()
        case .title:
            base = all.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .date:
            base = all.sorted { lhs, rhs in
                let lp = lhs.workingStart ?? lhs.dueDate
                let rp = rhs.workingStart ?? rhs.dueDate
                switch (lp, rp) {
                case (nil, nil):
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                case (_, nil):
                    return true
                case (nil, _):
                    return false
                case (let a?, let b?):
                    if a != b { return a < b }
                    // Primary equal. If both used working date, tie-break by due date.
                    if lhs.workingStart != nil && rhs.workingStart != nil {
                        switch (lhs.dueDate, rhs.dueDate) {
                        case (nil, nil): break
                        case (_, nil):   return true
                        case (nil, _):   return false
                        case (let da?, let db?):
                            if da != db { return da < db }
                        }
                    }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
        }
        return direction == .ascending ? base : base.reversed()
    }
}
