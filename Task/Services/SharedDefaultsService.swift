import Foundation
import os

enum SharedDefaultsService {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Task", category: "SharedDefaults")

    static let appGroupIdentifier = "group.com.ijustin.task"
    static let upcomingSnapshotKey = "task.upcomingSnapshot"
    static let boardListKey = "task.boardList"
    static let statusListKey = "task.statusList"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    struct UpcomingSnapshotEntry: Codable, Identifiable {
        var id: UUID
        var title: String
        var dueDate: Date?
        var workingStart: Date?
        var workingEnd: Date?
        var groupID: UUID? = nil
        var groupName: String
        var groupColorKey: String
        var groupSortIndex: Int?
        var boardID: UUID
        var boardEmoji: String
        var boardTitle: String
    }

    struct UpcomingSnapshot: Codable {
        var entries: [UpcomingSnapshotEntry] = []
        var updatedAt: Date = Date()
    }

    struct BoardListEntry: Codable, Identifiable {
        var id: UUID
        var title: String
        var iconEmoji: String
    }

    struct StatusListEntry: Codable, Identifiable {
        var id: UUID
        var boardID: UUID
        var boardEmoji: String
        var boardTitle: String
        var name: String
        var colorKey: String
        var sortIndex: Int
    }

    static func writeUpcoming(_ snapshot: UpcomingSnapshot) {
        guard let defaults = sharedDefaults else {
            logger.error("Failed to open App Group defaults for upcoming snapshot")
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(snapshot)
            defaults.set(data, forKey: upcomingSnapshotKey)
        } catch {
            logger.error("Failed to encode upcoming snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func readUpcoming() -> UpcomingSnapshot? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: upcomingSnapshotKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UpcomingSnapshot.self, from: data)
    }

    static func writeBoardList(_ boards: [BoardListEntry]) {
        guard let defaults = sharedDefaults else {
            logger.error("Failed to open App Group defaults for board list")
            return
        }
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(boards)
            defaults.set(data, forKey: boardListKey)
        } catch {
            logger.error("Failed to encode board list: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func readBoardList() -> [BoardListEntry] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: boardListKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([BoardListEntry].self, from: data)) ?? []
    }

    static func writeStatusList(_ statuses: [StatusListEntry]) {
        guard let defaults = sharedDefaults else {
            logger.error("Failed to open App Group defaults for status list")
            return
        }
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(statuses)
            defaults.set(data, forKey: statusListKey)
        } catch {
            logger.error("Failed to encode status list: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func readStatusList() -> [StatusListEntry] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: statusListKey) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([StatusListEntry].self, from: data)) ?? []
    }
}
