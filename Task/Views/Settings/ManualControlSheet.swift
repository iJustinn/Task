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

    let isImporting: Bool
    let onExport: () -> Void
    let onImport: () -> Void
    let onReset: () -> Void

    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    SettingsCardSection {
                        exportRow
                        SettingsRowDivider()
                        importRow
                        SettingsRowDivider()
                        resetRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Manual Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingResetConfirmation) {
                ConfirmationSheet(
                    icon: "trash.fill",
                    iconTint: .red,
                    title: "Reset All Data?",
                    message: "This will delete every group, tag, and task, then restore the six default groups. This can't be undone.",
                    confirmLabel: "Reset All Data"
                ) {
                    dismissThenRun(onReset)
                }
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
            }
        }
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
            HStack(spacing: 14) {
                SettingsIconTile(systemName: "trash.fill", color: .red)
                Text("Reset All Data")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
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

