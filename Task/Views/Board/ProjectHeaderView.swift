import SwiftUI
import SwiftData

struct ProjectHeaderView: View {
    let board: Board
    var layoutStyle: BoardLayoutStyle = .mobile
    let isDateFilterActive: Bool
    let onDateFilterTap: () -> Void
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var draftTitle: String = ""
    @State private var draftSubtitle: String = ""
    @State private var showIconPicker: Bool = false
    @State private var showingSort: Bool = false
    @FocusState private var titleFocused: Bool
    @FocusState private var subtitleFocused: Bool

    var body: some View {
        Group {
            switch layoutStyle {
            case .mobile:
                mobileHeader
            case .mac:
                macHeader
            }
        }
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
            .taskMacSheetFrame(width: 520, minHeight: 460)
            .taskSheetPresentation(detents: [.medium, .large], macHeight: 520)
        }
        .sheet(isPresented: $showingSort) {
            CardOrderPickerSheet(board: board)
                .environmentObject(settings)
                .taskSheetPresentation(macHeight: 520)
        }
    }

    private var mobileHeader: some View {
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

            HStack(spacing: 2) {
                headerIconButton(systemName: "arrow.up.arrow.down", tint: .primary, label: "Sort") {
                    showingSort = true
                }
                headerIconButton(systemName: "calendar", tint: isDateFilterActive ? .accentColor : .primary, label: "Date Filter") {
                    onDateFilterTap()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var macHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Button {
                    showIconPicker = true
                } label: {
                    Text(board.iconEmoji)
                        .font(.system(size: 42))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Board icon")

                VStack(alignment: .leading, spacing: 3) {
                    TextField("Title", text: $draftTitle)
                        .font(.system(size: 34, weight: .bold))
                        .textFieldStyle(.plain)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { commit() }

                    TextField("Subtitle", text: $draftSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .textFieldStyle(.plain)
                        .focused($subtitleFocused)
                        .submitLabel(.done)
                        .onSubmit { commit() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Label("Board", systemImage: "rectangle.3.group")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill))
                    )

                macToolbarButton(systemName: "arrow.up.arrow.down", label: "Sort", isActive: false) {
                    showingSort = true
                }

                macToolbarButton(systemName: "calendar", label: "Date", isActive: isDateFilterActive) {
                    onDateFilterTap()
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 28)
        .padding(.bottom, 8)
        .background(Color(uiColor: .systemBackground))
    }

    private func headerIconButton(systemName: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func macToolbarButton(
        systemName: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemName)
                .font(.subheadline)
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                )
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func commit() {
        let title = draftTitle.trimmingCharacters(in: .whitespaces)
        let subtitle = draftSubtitle.trimmingCharacters(in: .whitespaces)
        var changed = false
        if board.title != title {
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
