import Foundation
import SwiftData

@Model
final class TaskTag {
    var id: UUID = UUID()
    var name: String = ""
    var colorKeyRaw: String = ColorKey.gray.rawValue
    var sortIndex: Int = 0
    var createdAt: Date = Date()

    var board: Board?

    @Relationship(inverse: \TaskItem.tags)
    var tasks: [TaskItem]? = []

    init(name: String, colorKey: ColorKey = .gray, sortIndex: Int = 0) {
        self.name = name
        self.colorKeyRaw = colorKey.rawValue
        self.sortIndex = sortIndex
    }

    var colorKey: ColorKey {
        get { ColorKey(rawValue: colorKeyRaw) ?? .gray }
        set { colorKeyRaw = newValue.rawValue }
    }
}
