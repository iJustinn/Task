import SwiftUI

// MARK: - Flat choice picker

private protocol FlatSettingsChoice: Identifiable, Equatable {
    var pickerTitle: String { get }
    var pickerSubtitle: String? { get }
    var pickerSystemImage: String? { get }
    var pickerIconText: String? { get }
    var pickerTintColor: Color { get }
}

private extension FlatSettingsChoice {
    var pickerIconText: String? { nil }
}

private struct FlatSettingsChoicePicker<Option: FlatSettingsChoice>: View {
    let title: String
    let options: [Option]
    @Binding var selection: Option
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                                optionRow(option)
                                if index < options.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    private func optionRow(_ option: Option) -> some View {
        Button {
            selection = option
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                optionIcon(option)

                VStack(alignment: .leading, spacing: 5) {
                    Text(option.pickerTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let subtitle = option.pickerSubtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if selection == option {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.accent)
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func optionIcon(_ option: Option) -> some View {
        if let text = option.pickerIconText {
            Text(text)
                .font(.body.weight(.bold))
                .foregroundStyle(option.pickerTintColor)
                .frame(width: 34)
        } else if let systemImage = option.pickerSystemImage {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(option.pickerTintColor)
                .frame(width: 34)
        } else {
            Circle()
                .fill(option.pickerTintColor)
                .frame(width: 13, height: 13)
                .frame(width: 34)
        }
    }
}

extension AppTheme: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerTintColor: Color { tintColor }
}

extension AppLanguage: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerTintColor: Color { tintColor }
}

extension AppTimeFormat: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerIconText: String? { iconText }
    fileprivate var pickerTintColor: Color { tintColor }
}

extension AppAccent: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerTintColor: Color { color }
}

extension AppTextSize: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerTintColor: Color { tintColor }
}

extension AppColumnWidth: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerTintColor: Color { tintColor }
}

extension AppDateFormat: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerTintColor: Color { tintColor }
}

extension AppNotesPreview: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerTintColor: Color { tintColor }
}

extension AppDateFilterTarget: FlatSettingsChoice {
    fileprivate var pickerTitle: String { label }
    fileprivate var pickerSubtitle: String? { descriptor }
    fileprivate var pickerSystemImage: String? { systemImage }
    fileprivate var pickerTintColor: Color { tintColor }
}

struct ThemePickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "Theme", options: AppTheme.allCases, selection: $settings.theme)
    }
}

struct LanguagePickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "Language", options: AppLanguage.allCases, selection: $settings.language)
    }
}

struct TimeFormatPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "Time Format", options: AppTimeFormat.allCases, selection: $settings.timeFormat)
    }
}

struct TextSizePickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "Text Size", options: AppTextSize.allCases, selection: $settings.textSize)
    }
}

struct ColumnWidthPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "Group Width", options: AppColumnWidth.allCases, selection: $settings.columnWidth)
    }
}

struct AccentPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "App Accent", options: AppAccent.allCases, selection: $settings.accent)
    }
}

struct DateFormatPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "Date Format", options: AppDateFormat.allCases, selection: $settings.dateFormat)
    }
}

struct NotesPreviewPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "Notes Preview", options: AppNotesPreview.allCases, selection: $settings.notesPreview)
    }
}

struct DateFilterTargetPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    var body: some View {
        FlatSettingsChoicePicker(title: "Date Filter", options: AppDateFilterTarget.allCases, selection: $settings.dateFilterTarget)
    }
}

// MARK: - Reminder time picker

struct ReminderTimePickerSheet: View {
    let board: Board
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var digits: String = ""
    @State private var isPM: Bool = false
    @State private var hasUserInput: Bool = false

    private var uses24Hour: Bool { settings.timeFormat.uses24HourClock }

    private var parsedComponents: (hour: Int, minute: Int)? {
        guard !digits.isEmpty, let value = Int(digits) else { return nil }
        let minute = value % 100
        let hour = value / 100
        guard minute < 60 else { return nil }
        if uses24Hour {
            guard hour < 24 else { return nil }
            return (hour, minute)
        } else {
            guard (1...12).contains(hour) else { return nil }
            let normalized: Int
            if hour == 12 {
                normalized = isPM ? 12 : 0
            } else {
                normalized = isPM ? hour + 12 : hour
            }
            return (normalized, minute)
        }
    }

    private var hasError: Bool { !digits.isEmpty && parsedComponents == nil }

    private var hintText: String {
        uses24Hour ? String(localized: "Type 21:30 as 2130") : String(localized: "Type 9:30 as 930")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 14) {
                    VStack(spacing: 4) {
                        previewLabel
                        Text(hintText)
                            .font(.system(.footnote).weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                    keypadGrid
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle("Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { applyAndDismiss() }
                        .disabled(parsedComponents == nil)
                }
            }
            .onAppear { loadFromBoard() }
        }
    }

    private func loadFromBoard() {
        let total = board.reminderMinutesOfDay
        let hour24 = total / 60
        let minute = total % 60
        if uses24Hour {
            digits = String(format: "%d%02d", hour24, minute)
            isPM = false
        } else {
            let displayHour: Int
            switch hour24 {
            case 0:        displayHour = 12; isPM = false
            case 12:       displayHour = 12; isPM = true
            case 13...23:  displayHour = hour24 - 12; isPM = true
            default:       displayHour = hour24; isPM = false
            }
            digits = String(format: "%d%02d", displayHour, minute)
        }
        hasUserInput = false
    }

    @ViewBuilder
    private var previewLabel: some View {
        if let components = parsedComponents {
            Text(TimeFormatting.format(hour: components.hour, minute: components.minute, uses24Hour: uses24Hour))
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text(hasError ? "Invalid" : "Enter Time")
                .font(.system(size: 54, weight: .heavy))
                .foregroundColor(hasError ? .red : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var keypadGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                key("1") { append("1") }
                key("2") { append("2") }
                key("3") { append("3") }
                key(systemImage: "delete.left") { deleteLast() }
            }
            HStack(spacing: 12) {
                key("4") { append("4") }
                key("5") { append("5") }
                key("6") { append("6") }
                key("C") { clear() }
            }
            HStack(spacing: 12) {
                key("7") { append("7") }
                key("8") { append("8") }
                key("9") { append("9") }
                key("00") { append("00") }
            }
            HStack(spacing: 12) {
                key(String(localized: "Now"), isCompact: true) { setNow() }
                key("0") { append("0") }
                if uses24Hour {
                    key(String(localized: "AM/PM"), isCompact: true, isDisabled: true) {}
                } else {
                    key(isPM ? "PM" : "AM", isCompact: true) { isPM.toggle() }
                }
                key(systemImage: "checkmark", isPrimary: true) { applyAndDismiss() }
            }
        }
    }

    @ViewBuilder
    private func key(
        _ title: String? = nil,
        systemImage: String? = nil,
        isPrimary: Bool = false,
        isCompact: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: isPrimary ? 28 : 23, weight: .bold))
                } else if let title {
                    Text(title)
                        .font(.system(size: isCompact ? 18 : 28, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
            }
            .foregroundColor(isPrimary ? .white : (isDisabled ? .secondary.opacity(0.4) : .primary))
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(isPrimary ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            )
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func append(_ s: String) {
        let base = hasUserInput ? digits : ""
        let combined = base + s
        guard combined.count <= 4 else { return }
        digits = combined
        hasUserInput = true
    }

    private func deleteLast() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
        hasUserInput = true
    }

    private func clear() {
        digits = ""
        hasUserInput = true
    }

    private func setNow() {
        let now = Date()
        let cal = Calendar.current
        let hour24 = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        if uses24Hour {
            digits = String(format: "%d%02d", hour24, minute)
            isPM = false
        } else {
            let displayHour: Int
            switch hour24 {
            case 0:        displayHour = 12; isPM = false
            case 12:       displayHour = 12; isPM = true
            case 13...23:  displayHour = hour24 - 12; isPM = true
            default:       displayHour = hour24; isPM = false
            }
            digits = String(format: "%d%02d", displayHour, minute)
        }
        hasUserInput = true
    }

    private func applyAndDismiss() {
        guard let components = parsedComponents else { return }
        let newMinutes = components.hour * 60 + components.minute
        let changed = board.reminderMinutesOfDay != newMinutes
        board.reminderMinutesOfDay = newMinutes
        board.updatedAt = Date()
        try? context.save()
        if changed {
            // Existing UNCalendarNotificationTriggers were anchored to the old hour/
            // minute at scheduling time. Re-schedule every active reminder on this
            // board so they pick up the new time of day.
            rescheduleReminders()
        }
        dismiss()
    }

    private func rescheduleReminders() {
        for task in (board.tasks ?? []) where task.hasReminder {
            NotificationService.schedule(for: task)
        }
    }
}
