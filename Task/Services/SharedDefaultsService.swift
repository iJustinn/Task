import Foundation

enum SharedDefaultsService {
    static let appGroupIdentifier = "group.com.ijustin.task"
    static let upcomingSnapshotKey = "task.upcomingSnapshot"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    struct UpcomingSnapshotEntry: Codable, Identifiable {
        var id: UUID
        var title: String
        var dueDate: Date?
        var workingStart: Date?
        var workingEnd: Date?
        var groupName: String
        var groupColorKey: String
    }

    struct UpcomingSnapshot: Codable {
        var entries: [UpcomingSnapshotEntry] = []
        var updatedAt: Date = Date()
    }

    static func writeUpcoming(_ snapshot: UpcomingSnapshot) {
        guard let defaults = sharedDefaults else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: upcomingSnapshotKey)
        }
    }

    static func readUpcoming() -> UpcomingSnapshot? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: upcomingSnapshotKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UpcomingSnapshot.self, from: data)
    }
}
