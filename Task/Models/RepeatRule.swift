import Foundation

enum RepeatRule: String, CaseIterable, Identifiable {
    case none = ""
    case daily
    case weekly
    case biweekly
    case monthly
    case quarterly
    case annually

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:      return String(localized: "None")
        case .daily:     return String(localized: "Daily")
        case .weekly:    return String(localized: "Weekly")
        case .biweekly:  return String(localized: "Biweekly")
        case .monthly:   return String(localized: "Monthly")
        case .quarterly: return String(localized: "Quarterly")
        case .annually:  return String(localized: "Annually")
        }
    }

    /// Advance `date` by one occurrence of this rule. Returns `date` unchanged for `.none`.
    func advance(_ date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .none:      return date
        case .daily:     return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly:    return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .biweekly:  return calendar.date(byAdding: .weekOfYear, value: 2, to: date) ?? date
        case .monthly:   return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .annually:  return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
