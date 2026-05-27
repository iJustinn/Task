import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    var layoutStyle: BoardLayoutStyle = .mobile
    var onToggleChecked: (() -> Void)? = nil
    @EnvironmentObject private var settings: SettingsViewModel
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: layoutStyle == .mac ? 7 : 6) {
            titleRow

            if let tags = task.tags, !tags.isEmpty {
                FlowLayout(spacing: 4, lineSpacing: 4) {
                    ForEach(tags, id: \.id) { tag in
                        TagChip(name: tag.name, colorKey: tag.colorKey, compact: true)
                    }
                }
            }

            if let start = task.workingStart {
                let today = Calendar.current.startOfDay(for: Date())
                let upcoming = Calendar.current.startOfDay(for: start) > today
                DateRow(
                    start: start,
                    end: task.workingEnd,
                    tint: upcoming ? ColorKey.blue.foreground : ColorKey.red.foreground
                )
            }

            if let due = task.dueDate {
                let today = Calendar.current.startOfDay(for: Date())
                let upcoming = Calendar.current.startOfDay(for: due) > today
                DueDateRow(date: due, isUpcoming: upcoming)
            }

            if settings.notesPreview != .none, task.hasNotes {
                let lines = cardNotesPreviewLines(from: task.notes, limit: settings.notesPreview.lineLimit)
                if !lines.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(lines.indices, id: \.self) { i in
                            notePreviewRow(lines[i])
                        }
                    }
                    .padding(.top, 2)
                }
            }

            if task.repeatRule != .none || task.hasNotes || task.hasReminder {
                HStack(spacing: 6) {
                    footerDividerLine
                    if task.repeatRule != .none {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Repeats"))
                    }
                    if task.hasNotes {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Has notes"))
                    }
                    if task.hasReminder {
                        Image(systemName: "alarm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Has reminder"))
                    }
                    footerDividerLine
                }
                .padding(.top, 2)
            }
        }
        .padding(layoutStyle == .mac ? 11 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(cardFill)
                .shadow(color: cardShadowColor, radius: isHovered ? 7 : 2, x: 0, y: isHovered ? 3 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(cardBorder, lineWidth: 0.5)
        )
        .scaleEffect(isHovered && layoutStyle == .mac ? 1.006 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            if layoutStyle == .mac {
                isHovered = hovering
            }
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if task.showsCheckbox {
                checkboxControl
            }

            Text(task.title.isEmpty ? String(localized: "Untitled") : task.title)
                .font(titleFont)
                .foregroundStyle(isVisiblyChecked ? .secondary : .primary)
                .strikethrough(isVisiblyChecked, color: .secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isVisiblyChecked: Bool {
        task.showsCheckbox && task.isChecked
    }

    @ViewBuilder
    private var checkboxControl: some View {
        if let onToggleChecked {
            Button(action: onToggleChecked) {
                checkboxImage
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisiblyChecked ? Text("Mark task not done") : Text("Mark task done"))
        } else {
            checkboxImage
        }
    }

    private var checkboxImage: some View {
        Image(systemName: isVisiblyChecked ? "checkmark.square.fill" : "square")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isVisiblyChecked ? Color.accentColor : .secondary)
            .frame(width: 18, alignment: .center)
    }

    private var footerDividerLine: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 0.5)
    }

    private var titleFont: Font {
        layoutStyle == .mac ? .callout.weight(.semibold) : .subheadline.weight(.semibold)
    }

    private var cardCornerRadius: CGFloat {
        layoutStyle == .mac ? 7 : 10
    }

    private var cardFill: Color {
        layoutStyle == .mac ? Color(uiColor: .systemBackground) : Color(uiColor: .secondarySystemGroupedBackground)
    }

    private var cardBorder: Color {
        layoutStyle == .mac ? Color(uiColor: .separator).opacity(isHovered ? 0.5 : 0.28) : Color(uiColor: .systemGray5)
    }

    private var cardShadowColor: Color {
        layoutStyle == .mac ? Color.black.opacity(isHovered ? 0.08 : 0.025) : Color.black.opacity(0.04)
    }

    @ViewBuilder
    private func notePreviewRow(_ line: CardNotesPreviewLine) -> some View {
        let indentation = cardNoteIndentWidth(for: line.indentation)
        switch line.kind {
        case .text:
            previewText(line.text)
                .padding(.leading, indentation)
        case .task(let checked):
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 13, alignment: .center)

                previewText(line.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, indentation)
        }
    }

    private func previewText(_ text: AttributedString) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardNotesPreviewLine {
    enum Kind: Equatable {
        case text
        case task(checked: Bool)
    }

    let kind: Kind
    let text: AttributedString
    let indentation: String
}

func cardNotesPreviewLines(from raw: String, limit: Int) -> [CardNotesPreviewLine] {
    let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
    var lines: [CardNotesPreviewLine] = []
    for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
        if lines.count >= limit { break }
        let rawLineText = String(rawLine)
        let indentation = String(rawLineText.prefix { $0 == " " || $0 == "\t" })
        let trimmed = String(rawLineText.dropFirst(indentation.count))
        guard !trimmed.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
        lines.append(renderCardNotesPreviewLine(trimmed, indentation: indentation))
    }
    return lines
}

func cardNoteIndentWidth(for indentation: String) -> CGFloat {
    noteIndentWidth(for: indentation)
}

private func renderCardNotesPreviewLine(_ line: String, indentation: String) -> CardNotesPreviewLine {
    var content = line
    var prefix: String? = nil
    var kind: CardNotesPreviewLine.Kind = .text

    if content.hasPrefix("### ") {
        content.removeFirst(4)
    } else if content.hasPrefix("## ") {
        content.removeFirst(3)
    } else if content.hasPrefix("# ") {
        content.removeFirst(2)
    } else if let checked = stripCardTaskMarker(&content) {
        kind = .task(checked: checked)
    } else if content.hasPrefix("- ") || content.hasPrefix("* ") {
        content.removeFirst(2)
        prefix = "• "
    }

    content = content.trimmingCharacters(in: .whitespaces)
    let body = attributedCardPreviewText(content)

    if let prefix {
        return CardNotesPreviewLine(kind: kind, text: AttributedString(prefix) + body, indentation: indentation)
    }
    return CardNotesPreviewLine(kind: kind, text: body, indentation: indentation)
}

private func attributedCardPreviewText(_ raw: String) -> AttributedString {
    (try? AttributedString(
        markdown: raw,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(raw)
}

/// Returns `true` for checked, `false` for unchecked, or `nil` if the line isn't a task.
/// Strips the matched marker (with optional bullet + brackets + trailing space) from `content`.
private func stripCardTaskMarker(_ content: inout String) -> Bool? {
    let patterns: [(String, Bool)] = [
        ("- [x] ", true),  ("- [X] ", true),
        ("* [x] ", true),  ("* [X] ", true),
        ("- [ ] ", false), ("* [ ] ", false),
        ("- [] ",  false), ("* [] ",  false),
        ("[x] ", true), ("[X] ", true),
        ("[ ] ", false), ("[] ", false)
    ]
    for (token, checked) in patterns where content.hasPrefix(token) {
        content.removeFirst(token.count)
        return checked
    }
    return nil
}
