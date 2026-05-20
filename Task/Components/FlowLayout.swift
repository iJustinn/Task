import SwiftUI

/// A simple wrapping layout — lays out its subviews left-to-right and wraps to the next line
/// when the proposed width is exceeded. Used for tag chips so they wrap instead of getting squished.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // If the proposed width is unspecified, force the worst-case (one subview per row)
        // so the parent reserves enough vertical space and the wrapped layout never
        // overflows under the next sibling in a VStack.
        let maxWidth: CGFloat
        if let w = proposal.width, w.isFinite, w > 0 {
            maxWidth = w
        } else {
            maxWidth = 0
        }
        let arrangement = arrange(subviews: subviews, maxWidth: maxWidth)
        // Critical: return the *proposed* width (when given) so the parent VStack gives us
        // the full container width during placement. Otherwise it would size us to the
        // longest line and placeSubviews would receive a narrower bounds.width — causing
        // a second wrap that overflows past the height we just reported.
        let reportedWidth: CGFloat
        if let w = proposal.width, w.isFinite, w > 0 {
            reportedWidth = w
        } else {
            reportedWidth = arrangement.size.width
        }
        return CGSize(width: reportedWidth, height: arrangement.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Mirror sizeThatFits's width choice exactly. Using bounds.width here breaks when
        // the proposal said one thing but SwiftUI hands us a narrower bounds during placement —
        // the re-wrap then overflows past the height we already reserved.
        let maxWidth: CGFloat
        if let w = proposal.width, w.isFinite, w > 0 {
            maxWidth = w
        } else {
            maxWidth = bounds.width
        }
        let arrangement = arrange(subviews: subviews, maxWidth: maxWidth)
        for (index, frame) in arrangement.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            // Explicit infinite proposal forces Text-based subviews to report their unwrapped
            // single-line width, matching what TagChip with .fixedSize() will actually render.
            let size = subview.sizeThatFits(ProposedViewSize(width: .infinity, height: .infinity))
            if cursorX + size.width > maxWidth && cursorX > 0 {
                cursorY += lineHeight + lineSpacing
                cursorX = 0
                lineHeight = 0
            }
            frames.append(CGRect(x: cursorX, y: cursorY, width: size.width, height: size.height))
            cursorX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxLineWidth = max(maxLineWidth, cursorX - spacing)
        }

        let totalHeight = cursorY + lineHeight
        return (frames, CGSize(width: maxLineWidth, height: totalHeight))
    }
}
