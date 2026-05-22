import SwiftUI

// MARK: - Theme picker

struct ThemePickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                settings.theme = theme
                                dismiss()
                            } label: {
                                GridTile(
                                    title: theme.label,
                                    subtitle: theme.descriptor,
                                    systemImage: theme.systemImage,
                                    tintColor: theme.tintColor,
                                    isSelected: settings.theme == theme
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Theme")
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
    }
}

// MARK: - Accent picker

struct AccentPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppAccent.allCases) { accent in
                            Button {
                                settings.accent = accent
                                dismiss()
                            } label: {
                                GridTile(
                                    title: accent.label,
                                    subtitle: accent.descriptor,
                                    systemImage: accent.systemImage,
                                    tintColor: accent.color,
                                    isSelected: settings.accent == accent
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("App Accent")
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
    }
}

// MARK: - Time format picker

struct TimeFormatPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppTimeFormat.allCases) { format in
                            Button {
                                settings.timeFormat = format
                                dismiss()
                            } label: {
                                GridTile(
                                    title: format.label,
                                    subtitle: format.descriptor,
                                    systemImage: format.systemImage,
                                    iconText: format.iconText,
                                    tintColor: format.tintColor,
                                    isSelected: settings.timeFormat == format
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Time Format")
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
    }
}

// MARK: - Date format picker

struct DateFormatPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppDateFormat.allCases) { format in
                            Button {
                                settings.dateFormat = format
                                dismiss()
                            } label: {
                                GridTile(
                                    title: format.label,
                                    subtitle: format.descriptor,
                                    systemImage: format.systemImage,
                                    tintColor: format.tintColor,
                                    isSelected: settings.dateFormat == format
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Date Format")
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
    }
}

// MARK: - Notes preview picker

struct NotesPreviewPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppNotesPreview.allCases) { option in
                            Button {
                                settings.notesPreview = option
                                dismiss()
                            } label: {
                                GridTile(
                                    title: option.label,
                                    subtitle: option.descriptor,
                                    systemImage: option.systemImage,
                                    tintColor: option.tintColor,
                                    isSelected: settings.notesPreview == option
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Notes Preview")
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
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
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
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Text(hasError ? "Invalid" : "Enter Time")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
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
                        .font(.system(size: isCompact ? 18 : 28, weight: .bold, design: .rounded))
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
        board.reminderMinutesOfDay = components.hour * 60 + components.minute
        board.updatedAt = Date()
        try? context.save()
        dismiss()
    }
}

// MARK: - Text size picker

struct TextSizePickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppTextSize.allCases) { size in
                            Button {
                                settings.textSize = size
                                dismiss()
                            } label: {
                                GridTile(
                                    title: size.label,
                                    subtitle: size.descriptor,
                                    systemImage: size.systemImage,
                                    tintColor: size.tintColor,
                                    isSelected: settings.textSize == size
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Text Size")
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
    }
}

// MARK: - Column width picker

struct ColumnWidthPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppColumnWidth.allCases) { width in
                            Button {
                                settings.columnWidth = width
                                dismiss()
                            } label: {
                                GridTile(
                                    title: width.label,
                                    subtitle: width.descriptor,
                                    systemImage: width.systemImage,
                                    tintColor: width.tintColor,
                                    isSelected: settings.columnWidth == width
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Group Width")
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
    }
}

// MARK: - Language picker

struct LanguagePickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AppLanguage.allCases) { lang in
                            Button {
                                settings.language = lang
                                dismiss()
                            } label: {
                                GridTile(
                                    title: lang.label,
                                    subtitle: lang.descriptor,
                                    systemImage: lang.systemImage,
                                    tintColor: lang.tintColor,
                                    isSelected: settings.language == lang
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Language")
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
    }
}
