import SwiftUI

struct MarkdownNotesEditor: View {
    @Binding var text: String
    var placeholder: String = "Add notes"

    @State private var isEditing: Bool = false
    @FocusState private var fieldFocused: Bool

    private var showsEditor: Bool {
        isEditing || fieldFocused || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if showsEditor {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(4...20)
                .focused($fieldFocused)
                .onAppear {
                    if isEditing { fieldFocused = true }
                }
                .onChange(of: fieldFocused) { _, focused in
                    if !focused { isEditing = false }
                }
        } else {
            preview
        }
    }

    private var preview: some View {
        let lines = parseNoteLines(text)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(lines.indices, id: \.self) { i in
                row(for: lines[i])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func row(for line: NoteLine) -> some View {
        switch line.kind {
        case .heading(let level, let content):
            tappableText {
                Text(attributed(content))
                    .font(headingFont(level: level))
                    .fontWeight(.semibold)
            }
        case .bullet(let content):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundStyle(.secondary)
                tappableText {
                    Text(attributed(content))
                }
            }
        case .task(let checked, let content):
            HStack(alignment: .center, spacing: 10) {
                Button {
                    toggleTask(at: line.originalIndex)
                } label: {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .imageScale(.large)
                        .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                tappableText {
                    Text(attributed(content))
                        .strikethrough(checked, color: .secondary)
                        .foregroundStyle(checked ? Color.secondary : Color.primary)
                }
            }
        case .blank:
            Color.clear
                .frame(height: 8)
                .contentShape(Rectangle())
                .onTapGesture { beginEditing() }
        case .plain(let content):
            tappableText {
                Text(attributed(content))
            }
        }
    }

    @ViewBuilder
    private func tappableText<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { beginEditing() }
    }

    private func beginEditing() {
        isEditing = true
        fieldFocused = true
    }

    private func attributed(_ raw: String) -> AttributedString {
        if let parsed = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(raw)
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1: return .system(.title2, design: .rounded)
        case 2: return .system(.title3, design: .rounded)
        default: return .system(.headline, design: .rounded)
        }
    }

    private func toggleTask(at lineIndex: Int) {
        var lines = text.components(separatedBy: "\n")
        guard lineIndex >= 0, lineIndex < lines.count else { return }
        lines[lineIndex] = toggleTaskMarker(in: lines[lineIndex])
        text = lines.joined(separator: "\n")
    }
}

private struct NoteLine {
    enum Kind {
        case heading(level: Int, content: String)
        case bullet(content: String)
        case task(checked: Bool, content: String)
        case blank
        case plain(content: String)
    }
    let kind: Kind
    let originalIndex: Int
}

private func parseNoteLines(_ text: String) -> [NoteLine] {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    let rawLines = normalized.components(separatedBy: "\n")
    var result: [NoteLine] = []
    result.reserveCapacity(rawLines.count)

    for (index, raw) in rawLines.enumerated() {
        let trimmed = raw.drop(while: { $0 == " " || $0 == "\t" })

        if trimmed.isEmpty {
            result.append(NoteLine(kind: .blank, originalIndex: index))
            continue
        }

        if let headingKind = matchHeading(trimmed) {
            result.append(NoteLine(kind: headingKind, originalIndex: index))
            continue
        }

        if let listKind = matchBulletOrTask(trimmed) {
            result.append(NoteLine(kind: listKind, originalIndex: index))
            continue
        }

        result.append(NoteLine(kind: .plain(content: String(trimmed)), originalIndex: index))
    }
    return result
}

private func matchHeading(_ line: Substring) -> NoteLine.Kind? {
    if line.hasPrefix("### ") {
        return .heading(level: 3, content: String(line.dropFirst(4)))
    }
    if line.hasPrefix("## ") {
        return .heading(level: 2, content: String(line.dropFirst(3)))
    }
    if line.hasPrefix("# ") {
        return .heading(level: 1, content: String(line.dropFirst(2)))
    }
    return nil
}

private func matchBulletOrTask(_ line: Substring) -> NoteLine.Kind? {
    guard let marker = line.first, marker == "-" || marker == "*" else { return nil }
    let afterMarker = line.dropFirst()
    guard afterMarker.first == " " else { return nil }
    let body = afterMarker.dropFirst()

    if body.hasPrefix("[ ] ") {
        return .task(checked: false, content: String(body.dropFirst(4)))
    }
    if body.hasPrefix("[x] ") || body.hasPrefix("[X] ") {
        return .task(checked: true, content: String(body.dropFirst(4)))
    }
    if body.hasPrefix("[] ") {
        return .task(checked: false, content: String(body.dropFirst(3)))
    }
    if body == "[ ]" {
        return .task(checked: false, content: "")
    }
    if body == "[x]" || body == "[X]" {
        return .task(checked: true, content: "")
    }
    if body == "[]" {
        return .task(checked: false, content: "")
    }
    return .bullet(content: String(body))
}

private func toggleTaskMarker(in line: String) -> String {
    var cursor = line.startIndex
    while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
        cursor = line.index(after: cursor)
    }
    guard cursor < line.endIndex, line[cursor] == "-" || line[cursor] == "*" else { return line }
    let afterMarker = line.index(after: cursor)
    guard afterMarker < line.endIndex, line[afterMarker] == " " else { return line }
    let boxStart = line.index(after: afterMarker)
    let remainder = line[boxStart...]

    if remainder.hasPrefix("[ ]") {
        let end = line.index(boxStart, offsetBy: 3)
        return line.replacingCharacters(in: boxStart..<end, with: "[x]")
    }
    if remainder.hasPrefix("[x]") || remainder.hasPrefix("[X]") {
        let end = line.index(boxStart, offsetBy: 3)
        return line.replacingCharacters(in: boxStart..<end, with: "[ ]")
    }
    if remainder.hasPrefix("[]") {
        let end = line.index(boxStart, offsetBy: 2)
        return line.replacingCharacters(in: boxStart..<end, with: "[x]")
    }
    return line
}
