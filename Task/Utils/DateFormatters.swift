import Foundation

enum TaskDateFormat {
    /// Mutated when the user picks a non-system language in Settings so dates render
    /// in the same locale as the surrounding UI (rather than the device locale).
    nonisolated(unsafe) static var locale: Locale = .autoupdatingCurrent {
        didSet {
            guard oldValue != locale else { return }
            styledFormatters.removeAll()
        }
    }

    /// The user's chosen Date Format. Mirrored from `SettingsViewModel.dateFormat`
    /// so nonisolated contexts (e.g. `NotificationService`) can render dates in the
    /// same style as the rest of the app without crossing the `@MainActor` boundary.
    nonisolated(unsafe) static var currentStyle: AppDateFormat = .shortText

    private nonisolated(unsafe) static var styledFormatters: [String: DateFormatter] = [:]

    private static func formatter(for style: AppDateFormat) -> DateFormatter {
        if let cached = styledFormatters[style.rawValue] { return cached }
        let f = DateFormatter()
        f.locale = locale
        switch style {
        case .shortNumeric: f.dateFormat = "MM.dd"
        case .shortText:    f.setLocalizedDateFormatFromTemplate("MMMd")
        case .longNumeric:  f.dateFormat = "yyyy.MM.dd"
        case .longText:     f.setLocalizedDateFormatFromTemplate("MMMdy")
        }
        styledFormatters[style.rawValue] = f
        return f
    }

    static func format(_ date: Date, style: AppDateFormat) -> String {
        formatter(for: style).string(from: date)
    }

    static func formatRange(_ start: Date, _ end: Date?, style: AppDateFormat) -> String {
        guard let end, Calendar.current.startOfDay(for: end) != Calendar.current.startOfDay(for: start) else {
            return format(start, style: style)
        }
        return "\(format(start, style: style)) → \(format(end, style: style))"
    }

    /// The time-of-day a date carries, or `nil` when it sits at midnight — i.e. the
    /// task has no Specific Time and the reminder uses the board's Reminder Time.
    private static func timeString(for date: Date) -> String? {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        guard hour != 0 || minute != 0 else { return nil }
        return TimeFormatting.format(hour: hour, minute: minute, uses24Hour: TimeFormatting.systemUses24HourClock())
    }

    /// Like `format`, but appends the date's time-of-day when it carries one.
    static func formatWithTime(_ date: Date, style: AppDateFormat) -> String {
        guard let time = timeString(for: date) else { return format(date, style: style) }
        return "\(format(date, style: style)), \(time)"
    }

    /// Like `formatRange`, but appends the start's time-of-day when it carries one.
    /// Only the start can hold a Specific Time; the end stays day-level.
    static func formatRangeWithTime(_ start: Date, _ end: Date?, style: AppDateFormat) -> String {
        guard let end, Calendar.current.startOfDay(for: end) != Calendar.current.startOfDay(for: start) else {
            return formatWithTime(start, style: style)
        }
        return "\(formatWithTime(start, style: style)) → \(format(end, style: style))"
    }
}

enum TimeFormatting {
    static func systemUses24HourClock(locale: Locale = .autoupdatingCurrent) -> Bool {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? ""
        return !template.lowercased().contains("a")
    }

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
        let suffix = isPM ? String(localized: "PM") : String(localized: "AM")
        return String(format: "%d:%02d %@", displayHour, minute, suffix)
    }
}
