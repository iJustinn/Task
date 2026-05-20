import Foundation
import SwiftData

@Model
final class TaskTag {
    var id: UUID = UUID()
    var name: String = ""
    var colorKeyRaw: String = ColorKey.gray.rawValue
    var createdAt: Date = Date()

    var board: Board?

    @Relationship(inverse: \TaskItem.tags)
    var tasks: [TaskItem]? = []

    init(name: String, colorKey: ColorKey = .gray) {
        self.name = name
        self.colorKeyRaw = colorKey.rawValue
    }

    var colorKey: ColorKey {
        get { ColorKey(rawValue: colorKeyRaw) ?? .gray }
        set { colorKeyRaw = newValue.rawValue }
    }
}
