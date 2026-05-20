import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    let board: Board
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var activeSheet: AppearanceSheet?
    @State private var activeAboutSheet: AboutSheet?
    @State private var showingManualControl = false
    @State private var showingCardOrder = false
    @State private var showingDefaultStatus = false
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var exportDocument = TaskExportDocument()
    @State private var exportFileName = DataImportExport.defaultExportFileName()
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var resultAlert: ResultAlert?
    @State private var importOrphanMessage: String? = nil

    private enum AppearanceSheet: String, Identifiable {
        case theme, language, textSize, columnWidth, accent, icon, timeFormat, reminderTime
        var id: String { rawValue }
    }

    private enum AboutSheet: String, Identifiable {
        case howToUse, feedback, privacy, disclaimer, copyright
        var id: String { rawValue }
    }

    private enum ResultAlert: String, Identifiable {
        case importSuccess, importFailure, exportSuccess, exportFailure
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        appearanceSection
                        defaultSection
                        customizationSection
                        dataSection
                        aboutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
                if isImporting {
                    ProgressOverlay(title: "Importing Data", message: "Restoring your tasks, tags, and groups…")
                }
                if isExporting {
                    ProgressOverlay(title: "Exporting Data", message: "Preparing your task export…")
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isImporting)
            .animation(.easeInOut(duration: 0.18), value: isExporting)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
            }
            .sheet(item: $activeAboutSheet) { sheet in
                aboutSheetContent(for: sheet)
            }
            .sheet(isPresented: $showingCardOrder) {
                CardOrderPickerSheet()
                    .environmentObject(settings)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingDefaultStatus) {
                DefaultStatusPickerSheet(board: board)
                    .environmentObject(settings)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingManualControl) {
                ManualControlSheet(
                    isImporting: isImporting,
                    onExport: { performExport() },
                    onImport: { showingImportPicker = true },
                    onReset: { performReset() }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fileExporter(
                isPresented: $showingExportPicker,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFileName
            ) { result in
                if case .success = result {
                    resultAlert = .exportSuccess
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert(item: $resultAlert) { kind in
                switch kind {
                case .importSuccess:
                    let body = importOrphanMessage ?? String(localized: "Your data has been imported successfully.")
                    return Alert(
                        title: Text("Import Successful"),
                        message: Text(body),
                        dismissButton: .default(Text("OK"))
                    )
                case .importFailure:
                    return Alert(
                        title: Text("Import Failed"),
                        message: Text("Couldn't read that file. Make sure it's a Task export JSON."),
                        dismissButton: .default(Text("OK"))
                    )
                case .exportSuccess:
                    return Alert(
                        title: Text("Export Successful"),
                        message: Text("Your data has been exported successfully."),
                        dismissButton: .default(Text("OK"))
                    )
                case .exportFailure:
                    return Alert(
                        title: Text("Export Failed"),
                        message: Text("Couldn't prepare your data for export."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .preferredColorScheme(settings.theme.colorScheme)
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        SettingsCardSection("Appearance") {
            SettingsButtonRow(
                title: "Theme",
                systemName: settings.theme.systemImage,
                tintColor: settings.theme.tintColor,
                action: { activeSheet = .theme }
            ) {
                trailing(value: settings.theme.label)
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Language",
                systemName: settings.language.systemImage,
                tintColor: settings.language.tintColor,
                action: { activeSheet = .language }
            ) {
                trailing(value: settings.language.label)
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Time Format",
                systemName: timeFormatRowSystemName,
                tintColor: settings.timeFormat.tintColor,
                action: { activeSheet = .timeFormat }
            ) {
                trailing(value: settings.timeFormat.settingsLabel)
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Text Size",
                systemName: settings.textSize.systemImage,
                tintColor: settings.textSize.tintColor,
                action: { activeSheet = .textSize }
            ) {
                trailing(value: settings.textSize.label)
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Group Width",
                systemName: settings.columnWidth.systemImage,
                tintColor: settings.columnWidth.tintColor,
                action: { activeSheet = .columnWidth }
            ) {
                trailing(value: settings.columnWidth.label)
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "App Accent",
                systemName: settings.accent.systemImage,
                tintColor: settings.accent.color,
                action: { activeSheet = .accent }
            ) {
                trailing(value: settings.accent.label)
            }
            if UIApplication.shared.supportsAlternateIcons {
                SettingsRowDivider()
                SettingsButtonRow(
                    title: "Icon",
                    systemName: "app.fill",
                    tintColor: .indigo,
                    action: { activeSheet = .icon }
                ) {
                    trailing(value: settings.appIcon.title)
                }
            }
        }
    }

    private var defaultSection: some View {
        SettingsCardSection("Default") {
            SettingsButtonRow(
                title: "Status",
                systemName: "circle.fill",
                tintColor: defaultStatusTint,
                action: { showingDefaultStatus = true }
            ) {
                trailing(value: defaultStatusSummary)
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Card Order",
                systemName: settings.cardSortField.systemImage,
                tintColor: settings.cardSortField.tintColor,
                action: { showingCardOrder = true }
            ) {
                trailing(value: cardOrderSummary)
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Reminder Time",
                systemName: "bell.badge.fill",
                tintColor: .red,
                action: { activeSheet = .reminderTime }
            ) {
                trailing(value: reminderTimeSummary)
            }
        }
    }

    private var defaultStatusSummary: String {
        settings.defaultGroup(in: board)?.name ?? "—"
    }

    private var defaultStatusTint: Color {
        settings.defaultGroup(in: board)?.colorKey.foreground ?? .gray
    }

    private var cardOrderSummary: String {
        if settings.cardSortField == .manual {
            return settings.cardSortField.label
        }
        return "\(settings.cardSortField.label) · \(settings.cardSortDirection.label)"
    }

    private var timeFormatRowSystemName: String {
        switch settings.timeFormat {
        case .system:         return "clock.badge.checkmark.fill"
        case .twelveHour:     return "clock.fill"
        case .twentyFourHour: return "timer"
        }
    }

    private var reminderTimeSummary: String {
        let total = settings.reminderMinutesOfDay
        return TimeFormatting.format(
            hour: total / 60,
            minute: total % 60,
            uses24Hour: settings.timeFormat.uses24HourClock
        )
    }

    private var customizationSection: some View {
        SettingsCardSection("Customization") {
            NavigationLink {
                ManageGroupsView(board: board)
            } label: {
                SettingsRowLabel(
                    title: "Groups",
                    value: "\(board.orderedGroups.count)",
                    systemName: "rectangle.3.group.fill",
                    tintColor: .pink,
                    accessory: .chevron
                )
            }
            .buttonStyle(.plain)
            SettingsRowDivider()
            NavigationLink {
                ManageTagsView(board: board)
            } label: {
                SettingsRowLabel(
                    title: "Tags",
                    value: "\(board.orderedTags.count)",
                    systemName: "tag.fill",
                    tintColor: .orange,
                    accessory: .chevron
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var dataSection: some View {
        SettingsCardSection("Data") {
            SettingsRowLabel(
                title: "iCloud Sync",
                value: "Coming Soon",
                systemName: "icloud.fill",
                tintColor: .blue
            )
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Manual Control",
                systemName: "externaldrive.fill",
                tintColor: .orange,
                action: { showingManualControl = true }
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    private var aboutSection: some View {
        SettingsCardSection("About") {
            SettingsButtonRow(
                title: "How to Use",
                systemName: "questionmark.circle.fill",
                tintColor: .teal,
                action: { activeAboutSheet = .howToUse }
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Feedback",
                systemName: "message.fill",
                tintColor: .blue,
                action: { activeAboutSheet = .feedback }
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Privacy",
                systemName: "hand.raised.fill",
                tintColor: .green,
                action: { activeAboutSheet = .privacy }
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Disclaimer",
                systemName: "exclamationmark.triangle.fill",
                tintColor: .yellow,
                action: { activeAboutSheet = .disclaimer }
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            SettingsRowDivider()
            SettingsButtonRow(
                title: "Copyright",
                systemName: "c.circle.fill",
                tintColor: .purple,
                action: { activeAboutSheet = .copyright }
            ) {
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            SettingsRowDivider()
            SettingsRowLabel(
                title: "Version",
                value: appVersion,
                systemName: "info.circle.fill",
                tintColor: .gray
            )
        }
    }

    @ViewBuilder
    private func aboutSheetContent(for sheet: AboutSheet) -> some View {
        switch sheet {
        case .howToUse:
            HowToUseSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .feedback:
            FeedbackSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .privacy:
            PrivacySheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .disclaimer:
            DisclaimerSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .copyright:
            CopyrightSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func trailing(value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for sheet: AppearanceSheet) -> some View {
        switch sheet {
        case .theme:
            ThemePickerSheet()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .language:
            LanguagePickerSheet()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .textSize:
            TextSizePickerSheet()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .columnWidth:
            ColumnWidthPickerSheet()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .accent:
            AccentPickerSheet()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .icon:
            IconPickerSheet()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .timeFormat:
            TimeFormatPickerSheet()
                .environmentObject(settings)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .reminderTime:
            ReminderTimePickerSheet()
                .environmentObject(settings)
                .presentationDetents([.height(560)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Data actions

    private func performExport() {
        isExporting = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let data = DataImportExport.exportData(context: context) else {
                isExporting = false
                resultAlert = .exportFailure
                return
            }
            exportDocument = TaskExportDocument(data: data)
            exportFileName = DataImportExport.defaultExportFileName()
            isExporting = false
            showingExportPicker = true
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            resultAlert = .importFailure
            return
        }
        isImporting = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            let outcome = await DataImportExport.importData(data, context: context)
            isImporting = false
            if outcome.success {
                importOrphanMessage = orphanMessage(for: outcome)
                resultAlert = .importSuccess
            } else {
                importOrphanMessage = nil
                resultAlert = .importFailure
            }
        }
    }

    private func orphanMessage(for outcome: ImportResult) -> String? {
        let pieces = [
            outcome.orphanTasks > 0 ? String(localized: "\(outcome.orphanTasks) task(s) moved to the first group because their original group wasn't in the file.") : nil,
            outcome.orphanTagRefs > 0 ? String(localized: "\(outcome.orphanTagRefs) tag reference(s) couldn't be resolved and were dropped.") : nil
        ].compactMap { $0 }
        guard !pieces.isEmpty else { return nil }
        return String(localized: "Your data has been imported.") + "\n\n" + pieces.joined(separator: "\n")
    }

    private func performReset() {
        Task { @MainActor in
            await DataImportExport.resetAll(context: context)
        }
    }

    private var appVersion: String { AppInfo.versionAndBuild }
}
