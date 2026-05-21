import Foundation
import SwiftUI

enum WidgetColorKey: String, Codable {
    case purple, blue, red, yellow, green, pink, gray

    var hue: Color {
        switch self {
        case .purple: return Color(red: 0.55, green: 0.42, blue: 0.78)
        case .blue:   return Color(red: 0.30, green: 0.55, blue: 0.85)
        case .red:    return Color(red: 0.85, green: 0.40, blue: 0.40)
        case .yellow: return Color(red: 0.78, green: 0.62, blue: 0.20)
        case .green:  return Color(red: 0.36, green: 0.65, blue: 0.45)
        case .pink:   return Color(red: 0.85, green: 0.45, blue: 0.58)
        case .gray:   return Color(red: 0.45, green: 0.45, blue: 0.48)
        }
    }

    var background: Color { hue.opacity(0.16) }
}

struct WidgetUpcomingEntry: Codable, Identifiable {
    var id: UUID
    var title: String
    var dueDate: Date?
    var workingStart: Date?
    var workingEnd: Date?
    var groupName: String
    var groupColorKey: String
    var boardID: UUID?
    var boardEmoji: String?
    var boardTitle: String?

    var primaryDate: Date? {
        dueDate ?? workingEnd ?? workingStart
    }

    var widgetColor: WidgetColorKey {
        WidgetColorKey(rawValue: groupColorKey) ?? .gray
    }
}

struct WidgetUpcomingSnapshot: Codable {
    var entries: [WidgetUpcomingEntry] = []
    var updatedAt: Date = Date()
}

struct WidgetBoardListEntry: Codable, Identifiable {
    var id: UUID
    var title: String
    var iconEmoji: String
}

enum WidgetSharedDefaults {
    static let appGroupIdentifier = "group.com.ijustin.task"
    static let upcomingSnapshotKey = "task.upcomingSnapshot"
    static let boardListKey = "task.boardList"

    static func read() -> WidgetUpcomingSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: upcomingSnapshotKey) else {
            return WidgetUpcomingSnapshot()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(WidgetUpcomingSnapshot.self, from: data)) ?? WidgetUpcomingSnapshot()
    }

    static func readBoardList() -> [WidgetBoardListEntry] {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: boardListKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([WidgetBoardListEntry].self, from: data)) ?? []
    }
}
