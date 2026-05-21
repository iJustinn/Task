import Foundation

enum RepeatRule: String, CaseIterable, Identifiable {
    case none = ""
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:    return String(localized: "None")
        case .daily:   return String(localized: "Daily")
        case .weekly:  return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        }
    }

    /// Advance `date` by one occurrence of this rule. Returns `date` unchanged for `.none`.
    func advance(_ date: Date, calendar: Calendar = .current) -> Date {
        let component: Calendar.Component
        switch self {
        case .none:    return date
        case .daily:   component = .day
        case .weekly:  component = .weekOfYear
        case .monthly: component = .month
        }
        return calendar.date(byAdding: component, value: 1, to: date) ?? date
    }
}
