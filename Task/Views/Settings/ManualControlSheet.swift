import SwiftUI
import UniformTypeIdentifiers

struct TaskExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let bytes = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadUnknown)
        }
        self.data = bytes
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ManualControlSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel

    let isImporting: Bool
    let onExport: () -> Void
    let onImport: () -> Void
    let onReset: () -> Void

    @State private var showingResetConfirmation = false
    private var isMacLayout: Bool { PlatformLayout.prefersMacInterface }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(isMacLayout ? .systemGroupedBackground : .systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    SettingsCardSection {
                        exportRow
                        SettingsRowDivider()
                        importRow
                        SettingsRowDivider()
                        resetRow
                    }
                    .padding(.horizontal, isMacLayout ? 24 : 20)
                    .padding(.top, isMacLayout ? 16 : 8)
                    .padding(.bottom, isMacLayout ? 28 : 24)
                }
            }
            .navigationTitle("Manual Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingResetConfirmation) {
                ConfirmationSheet(
                    icon: "trash.fill",
                    iconTint: .red,
                    title: "Reset All Data?",
                    message: "This will delete every board, group, tag, and task on this device, then restore the three default boards (Personal, Study, Work) with five groups each. This can't be undone.",
                    confirmLabel: "Reset All Data"
                ) {
                    dismissThenRun(onReset)
                }
                .confirmationSheetPresentationStyle()
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    private var exportRow: some View {
        Button {
            dismissThenRun(onExport)
        } label: {
            SettingsRowLabel(
                title: "Export Data",
                systemName: "square.and.arrow.up.fill",
                tintColor: .blue,
                accessory: .chevron
            )
        }
        .buttonStyle(.plain)
    }

    private var importRow: some View {
        Button {
            dismissThenRun(onImport)
        } label: {
            SettingsRowLabel(
                title: "Import Data",
                systemName: "square.and.arrow.down.fill",
                tintColor: .green,
                accessory: .chevron
            )
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
        .opacity(isImporting ? 0.5 : 1)
    }

    private var resetRow: some View {
        Button {
            showingResetConfirmation = true
        } label: {
            HStack(spacing: isMacLayout ? 12 : 14) {
                SettingsIconTile(systemName: "trash.fill", color: .red)
                Text("Reset All Data")
                    .font(.system(isMacLayout ? .body : .headline))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.horizontal, isMacLayout ? 10 : 8)
            .padding(.vertical, isMacLayout ? 7 : 14)
            .frame(maxWidth: .infinity, minHeight: isMacLayout ? 46 : 70, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dismissThenRun(_ action: @escaping () -> Void) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            action()
        }
    }
}
