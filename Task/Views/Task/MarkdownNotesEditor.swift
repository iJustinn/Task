import SwiftUI
import UIKit

struct MarkdownNotesEditor: View {
    @Binding var text: String
    var placeholder: String = String(localized: "Add notes")
    var bodyFontSize: CGFloat = UIFont.preferredFont(forTextStyle: .body).pointSize

    @State private var isEditing: Bool = false
    @State private var editorFocused: Bool = false

    private var showsEditor: Bool {
        isEditing || editorFocused || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if showsEditor {
            LiveMarkdownTextView(
                text: $text,
                placeholder: placeholder,
                bodyFont: editorBodyFont,
                isFocused: $editorFocused
            )
                .frame(minHeight: 84)
                .onAppear {
                    if isEditing { editorFocused = true }
                }
                .onChange(of: editorFocused) { _, focused in
                    if !focused { isEditing = false }
                }
        } else {
            preview
        }
    }

    private var editorBodyFont: UIFont {
        UIFont.systemFont(ofSize: bodyFontSize)
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
        let indentation = noteIndentWidth(for: line.indentation)
        switch line.kind {
        case .heading(let level, let content):
            tappableText {
                Text(attributed(content))
                    .font(headingFont(level: level))
                    .fontWeight(.semibold)
            }
            .padding(.leading, indentation)
        case .bullet(let content):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.system(size: bodyFontSize))
                    .foregroundStyle(.secondary)
                tappableText {
                    Text(attributed(content))
                        .font(.system(size: bodyFontSize))
                }
            }
            .padding(.leading, indentation)
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
                        .font(.system(size: bodyFontSize))
                        .strikethrough(checked, color: .secondary)
                        .foregroundStyle(checked ? Color.secondary : Color.primary)
                }
            }
            .padding(.leading, indentation)
        case .blank:
            Color.clear
                .frame(height: 8)
                .padding(.leading, indentation)
                .contentShape(Rectangle())
                .onTapGesture { beginEditing() }
        case .plain(let content):
            tappableText {
                Text(attributed(content))
                    .font(.system(size: bodyFontSize))
            }
            .padding(.leading, indentation)
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
        editorFocused = true
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
        case 1: return .system(size: bodyFontSize + 7)
        case 2: return .system(size: bodyFontSize + 4)
        default: return .system(size: bodyFontSize + 2)
        }
    }

    private func toggleTask(at lineIndex: Int) {
        var lines = text.components(separatedBy: "\n")
        guard lineIndex >= 0, lineIndex < lines.count else { return }
        lines[lineIndex] = toggleTaskMarker(in: lines[lineIndex])
        text = lines.joined(separator: "\n")
    }
}

private struct LiveMarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let bodyFont: UIFont
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, bodyFont: bodyFont)
    }

    func makeUIView(context: Context) -> MarkdownUITextView {
        let textView = MarkdownUITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.adjustsFontForContentSizeCategory = false
        textView.font = bodyFont
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.placeholderLabel.text = placeholder
        textView.placeholderLabel.font = bodyFont
        context.coordinator.apply(text, to: textView)
        return textView
    }

    func updateUIView(_ textView: MarkdownUITextView, context: Context) {
        context.coordinator.bodyFont = bodyFont
        textView.placeholderLabel.text = placeholder
        textView.placeholderLabel.font = bodyFont
        textView.placeholderLabel.isHidden = !text.isEmpty

        if textView.text != text || textView.font?.pointSize != bodyFont.pointSize {
            textView.font = bodyFont
            context.coordinator.apply(text, to: textView)
        }

        if isFocused, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isFocused, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MarkdownUITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let target = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(target)
        return CGSize(width: width, height: max(84, size.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool
        var bodyFont: UIFont
        private var isApplying = false

        init(text: Binding<String>, isFocused: Binding<Bool>, bodyFont: UIFont) {
            _text = text
            _isFocused = isFocused
            self.bodyFont = bodyFont
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused = false
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplying else { return }
            text = textView.text
            apply(textView.text, to: textView)
        }

        func apply(_ raw: String, to textView: UITextView) {
            isApplying = true
            let selectedRange = textView.selectedRange
            textView.attributedText = markdownEditingAttributedText(raw, bodyFont: bodyFont)
            textView.typingAttributes = markdownEditingTypingAttributes(bodyFont: bodyFont)
            textView.selectedRange = NSRange(
                location: min(selectedRange.location, (raw as NSString).length),
                length: min(selectedRange.length, max(0, (raw as NSString).length - selectedRange.location))
            )
            if let markdownTextView = textView as? MarkdownUITextView {
                markdownTextView.placeholderLabel.isHidden = !raw.isEmpty
            }
            isApplying = false
        }
    }
}

final class MarkdownUITextView: UITextView {
    let placeholderLabel = UILabel()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

func markdownEditingAttributedText(
    _ raw: String,
    bodyFont: UIFont = UIFont.preferredFont(forTextStyle: .body)
) -> NSAttributedString {
    let attributed = NSMutableAttributedString(
        string: raw,
        attributes: [
            .font: bodyFont,
            .foregroundColor: UIColor.label
        ]
    )
    applyInlineMarkdownStyles(to: attributed, bodyFont: bodyFont)
    applyLineMarkdownStyles(to: attributed, bodyFont: bodyFont)
    return attributed
}

func markdownEditingTypingAttributes(
    bodyFont: UIFont = UIFont.preferredFont(forTextStyle: .body)
) -> [NSAttributedString.Key: Any] {
    [
        .font: bodyFont,
        .foregroundColor: UIColor.label
    ]
}

private func applyLineMarkdownStyles(to attributed: NSMutableAttributedString, bodyFont: UIFont) {
    let raw = attributed.string
    var location = 0

    for line in raw.components(separatedBy: "\n") {
        let lineLength = (line as NSString).length
        let lineRange = NSRange(location: location, length: lineLength)
        let trimmedOffset = line.prefix { $0 == " " || $0 == "\t" }.utf16.count
        let trimmed = String(line.dropFirst(trimmedOffset))

        if !trimmed.isEmpty {
            if trimmed.hasPrefix("# ") {
                attributed.addAttributes([.font: UIFont.systemFont(ofSize: bodyFont.pointSize + 7)], range: lineRange)
            } else if trimmed.hasPrefix("## ") {
                attributed.addAttributes([.font: UIFont.systemFont(ofSize: bodyFont.pointSize + 4)], range: lineRange)
            } else if trimmed.hasPrefix("### ") {
                attributed.addAttributes([.font: UIFont.systemFont(ofSize: bodyFont.pointSize + 2)], range: lineRange)
            } else if let markerLength = taskMarkerLength(in: trimmed) {
                let markerRange = NSRange(location: location + trimmedOffset, length: markerLength)
                attributed.addAttributes([
                    .font: UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .semibold),
                    .foregroundColor: UIColor.secondaryLabel
                ], range: markerRange)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let markerRange = NSRange(location: location + trimmedOffset, length: 1)
                attributed.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: markerRange)
            }
        }

        location += lineLength + 1
    }
}

private func applyInlineMarkdownStyles(to attributed: NSMutableAttributedString, bodyFont: UIFont) {
    applyRegex("\\*\\*[^\\n*]+\\*\\*", to: attributed) { range in
        attributed.addAttribute(.font, value: font(bodyFont, adding: .traitBold), range: range)
    }

    applyRegex("(?<!\\*)\\*[^\\n*]+\\*(?!\\*)", to: attributed) { range in
        attributed.addAttribute(.font, value: font(bodyFont, adding: .traitItalic), range: range)
    }
}

private func applyRegex(_ pattern: String, to attributed: NSMutableAttributedString, update: (NSRange) -> Void) {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
    let fullRange = NSRange(location: 0, length: (attributed.string as NSString).length)
    for match in regex.matches(in: attributed.string, range: fullRange) {
        update(match.range)
    }
}

private func font(_ base: UIFont, adding trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
    let traits = base.fontDescriptor.symbolicTraits.union(trait)
    guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
    return UIFont(descriptor: descriptor, size: base.pointSize)
}

private func taskMarkerLength(in trimmedLine: String) -> Int? {
    if trimmedLine.hasPrefix("[ ]") || trimmedLine.hasPrefix("[x]") || trimmedLine.hasPrefix("[X]") {
        return 3
    }
    if trimmedLine.hasPrefix("[]") {
        return 2
    }
    if trimmedLine.hasPrefix("- [ ]") || trimmedLine.hasPrefix("- [x]") || trimmedLine.hasPrefix("- [X]")
        || trimmedLine.hasPrefix("* [ ]") || trimmedLine.hasPrefix("* [x]") || trimmedLine.hasPrefix("* [X]") {
        return 5
    }
    if trimmedLine.hasPrefix("- []") || trimmedLine.hasPrefix("* []") {
        return 4
    }
    return nil
}

struct NoteLine {
    enum Kind {
        case heading(level: Int, content: String)
        case bullet(content: String)
        case task(checked: Bool, content: String)
        case blank
        case plain(content: String)
    }
    let kind: Kind
    let indentation: String
    let originalIndex: Int
}

func noteIndentWidth(for indentation: String) -> CGFloat {
    indentation.reduce(CGFloat.zero) { width, character in
        width + (character == "\t" ? 24 : 5)
    }
}

func parseNoteLines(_ text: String) -> [NoteLine] {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    let rawLines = normalized.components(separatedBy: "\n")
    var result: [NoteLine] = []
    result.reserveCapacity(rawLines.count)

    for (index, raw) in rawLines.enumerated() {
        let indentation = String(raw.prefix { $0 == " " || $0 == "\t" })
        let trimmed = raw.dropFirst(indentation.count)

        if trimmed.isEmpty {
            result.append(NoteLine(kind: .blank, indentation: indentation, originalIndex: index))
            continue
        }

        if let headingKind = matchHeading(trimmed) {
            result.append(NoteLine(kind: headingKind, indentation: indentation, originalIndex: index))
            continue
        }

        if let taskKind = matchBareTask(trimmed) {
            result.append(NoteLine(kind: taskKind, indentation: indentation, originalIndex: index))
            continue
        }

        if let listKind = matchBulletOrTask(trimmed) {
            result.append(NoteLine(kind: listKind, indentation: indentation, originalIndex: index))
            continue
        }

        result.append(NoteLine(kind: .plain(content: String(trimmed)), indentation: indentation, originalIndex: index))
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

private func matchBareTask(_ line: Substring) -> NoteLine.Kind? {
    matchTaskBody(line)
}

private func matchBulletOrTask(_ line: Substring) -> NoteLine.Kind? {
    guard let marker = line.first, marker == "-" || marker == "*" else { return nil }
    let afterMarker = line.dropFirst()
    guard afterMarker.first == " " else { return nil }
    let body = afterMarker.dropFirst()

    if let task = matchTaskBody(body) {
        return task
    }
    return .bullet(content: String(body))
}

private func matchTaskBody(_ body: Substring) -> NoteLine.Kind? {
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
    return nil
}

func toggleTaskMarker(in line: String) -> String {
    var cursor = line.startIndex
    while cursor < line.endIndex, line[cursor] == " " || line[cursor] == "\t" {
        cursor = line.index(after: cursor)
    }

    if let toggled = toggleTaskBox(in: line, at: cursor, checkedReplacement: "[]") {
        return toggled
    }

    guard cursor < line.endIndex, line[cursor] == "-" || line[cursor] == "*" else { return line }
    let afterMarker = line.index(after: cursor)
    guard afterMarker < line.endIndex, line[afterMarker] == " " else { return line }
    let boxStart = line.index(after: afterMarker)

    return toggleTaskBox(in: line, at: boxStart, checkedReplacement: "[ ]") ?? line
}

private func toggleTaskBox(in line: String, at boxStart: String.Index, checkedReplacement: String) -> String? {
    guard boxStart < line.endIndex else { return nil }
    let remainder = line[boxStart...]
    if remainder.hasPrefix("[ ]") {
        let end = line.index(boxStart, offsetBy: 3)
        return line.replacingCharacters(in: boxStart..<end, with: "[x]")
    }
    if remainder.hasPrefix("[x]") || remainder.hasPrefix("[X]") {
        let end = line.index(boxStart, offsetBy: 3)
        return line.replacingCharacters(in: boxStart..<end, with: checkedReplacement)
    }
    if remainder.hasPrefix("[]") {
        let end = line.index(boxStart, offsetBy: 2)
        return line.replacingCharacters(in: boxStart..<end, with: "[x]")
    }
    return nil
}
