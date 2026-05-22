import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title.isEmpty ? String(localized: "Untitled") : task.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                let lines = notesPreviewLines(from: task.notes, limit: settings.notesPreview.lineLimit)
                if !lines.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(lines.indices, id: \.self) { i in
                            Text(lines[i])
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var footerDividerLine: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 0.5)
    }

    private func notesPreviewLines(from raw: String, limit: Int) -> [AttributedString] {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        var lines: [AttributedString] = []
        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if lines.count >= limit { break }
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            lines.append(renderPreviewLine(trimmed))
        }
        return lines
    }

    private func renderPreviewLine(_ line: String) -> AttributedString {
        var content = line
        var prefix: String? = nil

        if content.hasPrefix("### ") {
            content.removeFirst(4)
        } else if content.hasPrefix("## ") {
            content.removeFirst(3)
        } else if content.hasPrefix("# ") {
            content.removeFirst(2)
        } else if let task = stripTaskMarker(&content) {
            prefix = task ? "☑ " : "☐ "
        } else if content.hasPrefix("- ") || content.hasPrefix("* ") {
            content.removeFirst(2)
            prefix = "• "
        }

        content = content.trimmingCharacters(in: .whitespaces)

        let body = (try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(content)

        if let prefix {
            return AttributedString(prefix) + body
        }
        return body
    }

    /// Returns `true` for checked, `false` for unchecked, or `nil` if the line isn't a task.
    /// Strips the matched marker (with optional bullet + brackets + trailing space) from `content`.
    private func stripTaskMarker(_ content: inout String) -> Bool? {
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
}
