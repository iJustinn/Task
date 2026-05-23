import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    var onToggleChecked: (() -> Void)? = nil
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                    }
                    if task.hasNotes {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if task.hasReminder {
                        Image(systemName: "alarm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    footerDividerLine
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(uiColor: .systemGray5), lineWidth: 0.5)
        )
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if task.showsCheckbox {
                checkboxControl
            }

            Text(task.title.isEmpty ? String(localized: "Untitled") : task.title)
                .font(.subheadline.weight(.semibold))
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

    @ViewBuilder
    private func notePreviewRow(_ line: CardNotesPreviewLine) -> some View {
        switch line.kind {
        case .text:
            previewText(line.text)
        case .task(let checked):
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 13, alignment: .center)

                previewText(line.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
}

func cardNotesPreviewLines(from raw: String, limit: Int) -> [CardNotesPreviewLine] {
    let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
    var lines: [CardNotesPreviewLine] = []
    for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
        if lines.count >= limit { break }
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }
        lines.append(renderCardNotesPreviewLine(trimmed))
    }
    return lines
}

private func renderCardNotesPreviewLine(_ line: String) -> CardNotesPreviewLine {
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
        return CardNotesPreviewLine(kind: kind, text: AttributedString(prefix) + body)
    }
    return CardNotesPreviewLine(kind: kind, text: body)
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
