import SwiftUI
import SwiftData

struct ProjectHeaderView: View {
    let board: Board
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var draftTitle: String = ""
    @State private var draftSubtitle: String = ""
    @State private var showIconPicker: Bool = false
    @State private var showingSort: Bool = false
    @State private var showingReminder: Bool = false
    @State private var showingDefaultStatus: Bool = false
    @FocusState private var titleFocused: Bool
    @FocusState private var subtitleFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                showIconPicker = true
            } label: {
                Text(board.iconEmoji)
                    .font(.system(size: 30))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Board icon")

            VStack(alignment: .leading, spacing: 4) {
                TextField("Title", text: $draftTitle)
                    .font(.title.weight(.bold))
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit { commit() }

                TextField("Subtitle", text: $draftSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .focused($subtitleFocused)
                    .submitLabel(.done)
                    .onSubmit { commit() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                headerIconButton(systemName: "flag.fill", tint: .primary, label: "Default Status") {
                    showingDefaultStatus = true
                }
                headerIconButton(systemName: "arrow.up.arrow.down", tint: .primary, label: "Sort") {
                    showingSort = true
                }
                headerIconButton(systemName: "bell.fill", tint: .primary, label: "Reminder Time") {
                    showingReminder = true
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onAppear {
            draftTitle = board.title
            draftSubtitle = board.subtitle
        }
        .onChange(of: board.id) { _, _ in
            draftTitle = board.title
            draftSubtitle = board.subtitle
        }
        .onChange(of: titleFocused) { _, focused in
            if !focused { commit() }
        }
        .onChange(of: subtitleFocused) { _, focused in
            if !focused { commit() }
        }
        .sheet(isPresented: $showIconPicker) {
            BoardIconPickerSheet(currentIcon: board.iconEmoji) { emoji in
                board.iconEmoji = emoji
                board.updatedAt = Date()
                try? context.save()
                UpcomingSnapshotBuilder.writeSnapshot(from: context)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSort) {
            CardOrderPickerSheet(board: board)
                .environmentObject(settings)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingReminder) {
            ReminderTimePickerSheet(board: board)
                .environmentObject(settings)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingDefaultStatus) {
            DefaultStatusPickerSheet(board: board)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func headerIconButton(systemName: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(Color(.secondarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func commit() {
        let title = draftTitle.trimmingCharacters(in: .whitespaces)
        let subtitle = draftSubtitle.trimmingCharacters(in: .whitespaces)
        var changed = false
        if !title.isEmpty, board.title != title {
            board.title = title
            board.updatedAt = Date()
            changed = true
        }
        if board.subtitle != subtitle {
            board.subtitle = subtitle
            board.updatedAt = Date()
            changed = true
        }
        try? context.save()
        if changed {
            UpcomingSnapshotBuilder.writeSnapshot(from: context)
        }
    }
}
