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

enum TimeFormatting {
    static func format(hour: Int, minute: Int, uses24Hour: Bool) -> String {
        if uses24Hour {
            return String(format: "%02d:%02d", hour, minute)
        }
        let isPM = hour >= 12
        let displayHour: Int
        switch hour {
        case 0:       displayHour = 12
        case 13...23: displayHour = hour - 12
        default:      displayHour = hour
        }
        return String(format: "%d:%02d %@", displayHour, minute, isPM ? "PM" : "AM")
    }
}
