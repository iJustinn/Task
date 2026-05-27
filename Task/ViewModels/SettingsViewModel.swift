import SwiftUI
import Combine
import UIKit
import UserNotifications

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .light:  return String(localized: "Light")
        case .dark:   return String(localized: "Dark")
        }
    }

    var descriptor: String {
        switch self {
        case .system: return String(localized: "Auto")
        case .light:  return String(localized: "Bright")
        case .dark:   return String(localized: "Dim")
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .system: return .teal
        case .light:  return .orange
        case .dark:   return .indigo
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let storageKey = "task.appLanguage"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    var descriptor: String {
        switch self {
        case .system: return String(localized: "Auto")
        case .english: return String(localized: "Latin")
        case .simplifiedChinese: return String(localized: "中文")
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "globe"
        case .english: return "character.book.closed.fill"
        case .simplifiedChinese: return "globe.asia.australia.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .system: return .gray
        case .english: return .blue
        case .simplifiedChinese: return .red
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .english: return Locale(identifier: "en")
        case .simplifiedChinese: return Locale(identifier: "zh-Hans")
        }
    }
}

enum AppTimeFormat: String, CaseIterable, Identifiable {
    case system
    case twelveHour
    case twentyFourHour

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system:         return String(localized: "System")
        case .twelveHour:     return String(localized: "12-hour")
        case .twentyFourHour: return String(localized: "24-hour")
        }
    }

    var descriptor: String {
        switch self {
        case .system:         return String(localized: "Follow Device")
        case .twelveHour:     return String(localized: "Always use 12-hour time")
        case .twentyFourHour: return String(localized: "Always use 24-hour time")
        }
    }

    var settingsLabel: String {
        switch self {
        case .system:                       return String(localized: "System")
        case .twelveHour, .twentyFourHour:  return label
        }
    }

    var systemImage: String? {
        switch self {
        case .system: return "clock.badge.checkmark.fill"
        default:      return nil
        }
    }

    var iconText: String? {
        switch self {
        case .twelveHour:     return "12"
        case .twentyFourHour: return "24"
        case .system:         return nil
        }
    }

    var tintColor: Color {
        switch self {
        case .system:         return .teal
        case .twelveHour:     return .orange
        case .twentyFourHour: return .blue
        }
    }

    var uses24HourClock: Bool {
        switch self {
        case .system:         return AppTimeFormat.systemUses24HourClock()
        case .twelveHour:     return false
        case .twentyFourHour: return true
        }
    }

    static func systemUses24HourClock(locale: Locale = .autoupdatingCurrent) -> Bool {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? ""
        return !template.lowercased().contains("a")
    }
}

enum AppAccent: String, CaseIterable, Identifiable {
    case blue
    case purple
    case pink
    case green
    case orange
    case teal
    case indigo
    case red
    case gray

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blue:   return String(localized: "Blue")
        case .purple: return String(localized: "Purple")
        case .pink:   return String(localized: "Pink")
        case .green:  return String(localized: "Green")
        case .orange: return String(localized: "Orange")
        case .teal:   return String(localized: "Teal")
        case .indigo: return String(localized: "Indigo")
        case .red:    return String(localized: "Red")
        case .gray:   return String(localized: "Gray")
        }
    }

    var descriptor: String {
        switch self {
        case .blue:   return String(localized: "Classic")
        case .purple: return String(localized: "Vivid")
        case .pink:   return String(localized: "Rose")
        case .green:  return String(localized: "Fresh")
        case .orange: return String(localized: "Warm")
        case .teal:   return String(localized: "Calm")
        case .indigo: return String(localized: "Deep")
        case .red:    return String(localized: "Bold")
        case .gray:   return String(localized: "Neutral")
        }
    }

    var systemImage: String {
        switch self {
        case .blue:   return "drop.fill"
        case .purple: return "sparkles"
        case .pink:   return "heart.fill"
        case .green:  return "leaf.fill"
        case .orange: return "sun.max.fill"
        case .teal:   return "water.waves"
        case .indigo: return "moon.stars.fill"
        case .red:    return "flame.fill"
        case .gray:   return "circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .blue:   return .blue
        case .purple: return .purple
        case .pink:   return .pink
        case .green:  return .green
        case .orange: return .orange
        case .teal:   return .teal
        case .indigo: return .indigo
        case .red:    return .red
        case .gray:   return .gray
        }
    }
}

enum AppIconOption: String, CaseIterable, Identifiable {
    case classic
    case rose
    case violet
    case midnight
    case neutral
    case light

    var id: String { rawValue }

    /// Name used by `setAlternateIconName(_:)`. `nil` means the primary AppIcon.
    var alternateName: String? {
        switch self {
        case .classic:  return nil
        case .rose:     return "Rose"
        case .violet:   return "Violet"
        case .midnight: return "Midnight"
        case .neutral:  return "Neutral"
        case .light:    return "Light"
        }
    }

    var previewAssetName: String {
        switch self {
        case .classic:  return "ClassicPreview"
        case .rose:     return "RosePreview"
        case .violet:   return "VioletPreview"
        case .midnight: return "MidnightPreview"
        case .neutral:  return "NeutralPreview"
        case .light:    return "LightPreview"
        }
    }

    var title: String {
        switch self {
        case .classic:  return String(localized: "Classic")
        case .rose:     return String(localized: "Rose")
        case .violet:   return String(localized: "Violet")
        case .midnight: return String(localized: "Midnight")
        case .neutral:  return String(localized: "Neutral")
        case .light:    return String(localized: "Light")
        }
    }

    var subtitle: String {
        switch self {
        case .classic:  return String(localized: "Original")
        case .rose:     return String(localized: "Pink")
        case .violet:   return String(localized: "Purple")
        case .midnight: return String(localized: "Black")
        case .neutral:  return String(localized: "Gray")
        case .light:    return String(localized: "White")
        }
    }
}

enum AppTextSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small:      return String(localized: "Small")
        case .medium:     return String(localized: "Medium")
        case .large:      return String(localized: "Large")
        case .extraLarge: return String(localized: "Extra Large")
        }
    }

    var descriptor: String {
        switch self {
        case .small:      return String(localized: "Compact")
        case .medium:     return String(localized: "Standard")
        case .large:      return String(localized: "Roomy")
        case .extraLarge: return String(localized: "Spacious")
        }
    }

    var systemImage: String {
        switch self {
        case .small:      return "textformat.size.smaller"
        case .medium:     return "textformat.size"
        case .large:      return "textformat.size.larger"
        case .extraLarge: return "textformat.size.larger"
        }
    }

    var tintColor: Color {
        switch self {
        case .small:      return .gray
        case .medium:     return .teal
        case .large:      return .blue
        case .extraLarge: return .purple
        }
    }

    var dynamicType: DynamicTypeSize {
        switch self {
        case .small:      return .large
        case .medium:     return .xLarge
        case .large:      return .xxLarge
        case .extraLarge: return .xxxLarge
        }
    }
}

enum CardSortField: String, CaseIterable, Identifiable {
    case manual
    case title
    case date

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return String(localized: "Manual")
        case .title:  return String(localized: "Title")
        case .date:   return String(localized: "Date")
        }
    }

    var descriptor: String {
        switch self {
        case .manual: return String(localized: "Drag to order")
        case .title:  return String(localized: "Alphabetical")
        case .date:   return String(localized: "Working then due")
        }
    }

    var systemImage: String {
        switch self {
        case .manual: return "list.bullet"
        case .title:  return "textformat"
        case .date:   return "calendar"
        }
    }

    var tintColor: Color {
        switch self {
        case .manual: return .gray
        case .title:  return .teal
        case .date:   return .blue
        }
    }
}

enum CardSortDirection: String, CaseIterable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ascending:  return String(localized: "Ascending")
        case .descending: return String(localized: "Descending")
        }
    }

    var descriptor: String {
        switch self {
        case .ascending:  return String(localized: "Low to High")
        case .descending: return String(localized: "High to Low")
        }
    }

    var systemImage: String {
        switch self {
        case .ascending:  return "arrow.up"
        case .descending: return "arrow.down"
        }
    }

    var tintColor: Color {
        switch self {
        case .ascending:  return .blue
        case .descending: return .indigo
        }
    }
}

enum AppDateFormat: String, CaseIterable, Identifiable {
    case shortNumeric
    case shortText
    case longNumeric
    case longText

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shortNumeric: return String(localized: "Short Numeric")
        case .shortText:    return String(localized: "Short Text")
        case .longNumeric:  return String(localized: "Long Numeric")
        case .longText:     return String(localized: "Long Text")
        }
    }

    var descriptor: String {
        switch self {
        case .shortNumeric: return "05.17"
        case .shortText:    return String(localized: "May 17")
        case .longNumeric:  return "2026.05.17"
        case .longText:     return String(localized: "May 17, 2026")
        }
    }

    var systemImage: String {
        switch self {
        case .shortNumeric: return "calendar"
        case .shortText:    return "calendar.badge.clock"
        case .longNumeric:  return "calendar.circle"
        case .longText:     return "calendar.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .shortNumeric: return .blue
        case .shortText:    return .teal
        case .longNumeric:  return .indigo
        case .longText:     return .purple
        }
    }

    var includesYear: Bool {
        switch self {
        case .shortNumeric, .shortText: return false
        case .longNumeric, .longText:   return true
        }
    }

    var usesTextMonth: Bool {
        switch self {
        case .shortNumeric, .longNumeric: return false
        case .shortText, .longText:       return true
        }
    }
}

enum AppNotesPreview: String, CaseIterable, Identifiable {
    case none
    case oneLine
    case twoLines
    case threeLines

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:       return String(localized: "Off")
        case .oneLine:    return String(localized: "1 Line")
        case .twoLines:   return String(localized: "2 Lines")
        case .threeLines: return String(localized: "3 Lines")
        }
    }

    var descriptor: String {
        switch self {
        case .none:       return String(localized: "Hidden")
        case .oneLine:    return String(localized: "Compact")
        case .twoLines:   return String(localized: "Standard")
        case .threeLines: return String(localized: "Roomy")
        }
    }

    var systemImage: String {
        switch self {
        case .none:       return "doc"
        case .oneLine:    return "doc.text"
        case .twoLines:   return "doc.text.fill"
        case .threeLines: return "doc.richtext.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .none:       return .gray
        case .oneLine:    return .teal
        case .twoLines:   return .green
        case .threeLines: return .indigo
        }
    }

    var lineLimit: Int {
        switch self {
        case .none:       return 0
        case .oneLine:    return 1
        case .twoLines:   return 2
        case .threeLines: return 3
        }
    }
}

enum AppDateFilterTarget: String, CaseIterable, Identifiable {
    case workingDate
    case dueDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .workingDate: return String(localized: "Working Date")
        case .dueDate:     return String(localized: "Due Date")
        }
    }

    var descriptor: String {
        switch self {
        case .workingDate: return String(localized: "Matches working days and ranges")
        case .dueDate:     return String(localized: "Matches due dates")
        }
    }

    var systemImage: String {
        switch self {
        case .workingDate: return "calendar"
        case .dueDate:     return "calendar.badge.exclamationmark"
        }
    }

    var tintColor: Color {
        switch self {
        case .workingDate: return .blue
        case .dueDate:     return .red
        }
    }
}

enum AppSearchMode: String, CaseIterable, Identifiable {
    case list
    case filter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .list:   return String(localized: "List")
        case .filter: return String(localized: "Filter")
        }
    }

    var descriptor: String {
        switch self {
        case .list:   return String(localized: "Show global results")
        case .filter: return String(localized: "Filter current board")
        }
    }

    var systemImage: String {
        switch self {
        case .list:   return "list.bullet.rectangle"
        case .filter: return "line.3.horizontal.decrease.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .list:   return .teal
        case .filter: return .blue
        }
    }
}

enum AppColumnWidth: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small:  return String(localized: "Small")
        case .medium: return String(localized: "Medium")
        case .large:  return String(localized: "Large")
        }
    }

    var descriptor: String {
        switch self {
        case .small:  return "180 pt"
        case .medium: return "200 pt"
        case .large:  return "220 pt"
        }
    }

    var systemImage: String {
        switch self {
        case .small:  return "rectangle.portrait"
        case .medium: return "rectangle"
        case .large:  return "rectangle.split.3x1"
        }
    }

    var tintColor: Color {
        switch self {
        case .small:  return .gray
        case .medium: return .blue
        case .large:  return .indigo
        }
    }

    var width: CGFloat {
        switch self {
        case .small:  return 180
        case .medium: return 200
        case .large:  return 220
        }
    }
}

enum ReminderDefaults {
    static let defaultMinutesOfDay = 9 * 60
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: SettingsViewModel.themeKey) }
    }

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
            TaskDateFormat.locale = language.locale
        }
    }

    @Published var accent: AppAccent {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: SettingsViewModel.accentKey) }
    }

    @Published var timeFormat: AppTimeFormat {
        didSet { UserDefaults.standard.set(timeFormat.rawValue, forKey: SettingsViewModel.timeFormatKey) }
    }

    @Published var appIcon: AppIconOption {
        didSet {
            UserDefaults.standard.set(appIcon.rawValue, forKey: SettingsViewModel.appIconKey)
            applyAppIcon()
        }
    }

    @Published var textSize: AppTextSize {
        didSet { UserDefaults.standard.set(textSize.rawValue, forKey: SettingsViewModel.textSizeKey) }
    }

    @Published var columnWidth: AppColumnWidth {
        didSet { UserDefaults.standard.set(columnWidth.rawValue, forKey: SettingsViewModel.columnWidthKey) }
    }

    @Published var dateFormat: AppDateFormat {
        didSet {
            UserDefaults.standard.set(dateFormat.rawValue, forKey: SettingsViewModel.dateFormatKey)
            TaskDateFormat.currentStyle = dateFormat
        }
    }

    @Published var notesPreview: AppNotesPreview {
        didSet { UserDefaults.standard.set(notesPreview.rawValue, forKey: SettingsViewModel.notesPreviewKey) }
    }

    @Published var dateFilterTarget: AppDateFilterTarget {
        didSet { UserDefaults.standard.set(dateFilterTarget.rawValue, forKey: SettingsViewModel.dateFilterTargetKey) }
    }

    @Published var searchMode: AppSearchMode {
        didSet { UserDefaults.standard.set(searchMode.rawValue, forKey: SettingsViewModel.searchModeKey) }
    }

    /// Cached so TaskDetailView can show a warning when the user enables a reminder
    /// while notifications are denied. Refresh from `RootView.task` and after the
    /// permission request.
    @Published var notificationsAuthorized: Bool? = nil

    func refreshNotificationAuthorization() async {
        let status = await NotificationService.currentAuthorizationStatus()
        notificationsAuthorized = (status == .authorized || status == .provisional || status == .ephemeral)
    }

    static let themeKey = "task.appTheme"
    static let accentKey = "task.appAccent"
    static let timeFormatKey = "task.timeFormat"
    static let appIconKey = "task.appIcon"
    static let textSizeKey = "task.textSize"
    static let columnWidthKey = "task.columnWidth"
    static let dateFormatKey = "task.dateFormat"
    static let notesPreviewKey = "task.notesPreview"
    static let legacyNotesPreviewKey = "task.notesPreviewEnabled"
    static let dateFilterTargetKey = "task.dateFilterTarget"
    static let searchModeKey = "task.searchMode"

    init() {
        let d = UserDefaults.standard
        self.theme = AppTheme(rawValue: d.string(forKey: SettingsViewModel.themeKey) ?? "") ?? .system
        let resolvedLanguage = AppLanguage(rawValue: d.string(forKey: AppLanguage.storageKey) ?? "") ?? .system
        self.language = resolvedLanguage
        self.accent = AppAccent(rawValue: d.string(forKey: SettingsViewModel.accentKey) ?? "") ?? .blue
        self.timeFormat = AppTimeFormat(rawValue: d.string(forKey: SettingsViewModel.timeFormatKey) ?? "") ?? .system
        self.appIcon = AppIconOption(rawValue: d.string(forKey: SettingsViewModel.appIconKey) ?? "") ?? .classic
        self.textSize = AppTextSize(rawValue: d.string(forKey: SettingsViewModel.textSizeKey) ?? "") ?? .medium
        self.columnWidth = AppColumnWidth(rawValue: d.string(forKey: SettingsViewModel.columnWidthKey) ?? "") ?? .medium
        let resolvedDateFormat = AppDateFormat(rawValue: d.string(forKey: SettingsViewModel.dateFormatKey) ?? "") ?? .shortText
        self.dateFormat = resolvedDateFormat
        let notesPreviewRaw = d.string(forKey: SettingsViewModel.notesPreviewKey)
            ?? d.string(forKey: SettingsViewModel.legacyNotesPreviewKey)
            ?? ""
        self.notesPreview = AppNotesPreview(rawValue: notesPreviewRaw) ?? .none
        self.dateFilterTarget = AppDateFilterTarget(rawValue: d.string(forKey: SettingsViewModel.dateFilterTargetKey) ?? "") ?? .workingDate
        self.searchMode = AppSearchMode(rawValue: d.string(forKey: SettingsViewModel.searchModeKey) ?? "") ?? .list
        TaskDateFormat.locale = resolvedLanguage.locale
        TaskDateFormat.currentStyle = resolvedDateFormat
    }

    private func applyAppIcon() {
        let target = appIcon.alternateName
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let current = UIApplication.shared.alternateIconName
        guard current != target else { return }
        UIApplication.shared.setAlternateIconName(target) { _ in }
    }
}
