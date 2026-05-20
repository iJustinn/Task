import SwiftUI
import SwiftData

struct ProjectHeaderView: View {
    let board: Board
    @Environment(\.modelContext) private var context

    @State private var draftTitle: String = ""
    @State private var draftSubtitle: String = ""
    @State private var showIconPicker: Bool = false
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onAppear {
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
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func commit() {
        let title = draftTitle.trimmingCharacters(in: .whitespaces)
        let subtitle = draftSubtitle.trimmingCharacters(in: .whitespaces)
        if !title.isEmpty, board.title != title {
            board.title = title
            board.updatedAt = Date()
        }
        if board.subtitle != subtitle {
            board.subtitle = subtitle
            board.updatedAt = Date()
        }
        try? context.save()
    }
}
