import Foundation

enum TaskDateFormat {
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let mediumWithTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func format(_ date: Date) -> String {
        medium.string(from: date)
    }

    static func formatRange(_ start: Date, _ end: Date?) -> String {
        guard let end, Calendar.current.startOfDay(for: end) != Calendar.current.startOfDay(for: start) else {
            return format(start)
        }
        return "\(format(start)) → \(format(end))"
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }
}
