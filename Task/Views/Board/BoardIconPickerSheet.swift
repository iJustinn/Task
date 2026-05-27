import SwiftUI

struct BoardIconPickerSheet: View {
    let currentIcon: String
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pendingIcon: String = ""
    private var isMacLayout: Bool { PlatformLayout.prefersMacInterface }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    private let icons: [String] = [
        "📌", "📝", "✅", "🎯", "🔥",
        "⭐", "✨", "💡", "🚀", "🏆",
        "📋", "📅", "🗓️", "⏰", "🔔",
        "💼", "🏠", "🎓", "📚", "🎨",
        "💻", "📱", "🛠️", "⚙️", "🧠",
        "❤️", "💎", "🌟", "🎁", "🌍",
        "🍎", "☕", "🍕", "🛒", "🏃",
        "✈️", "🚗", "🎬", "🎵", "🎮"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    if isMacLayout {
                        macSheetHeader
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(icons, id: \.self) { emoji in
                                Button {
                                    pendingIcon = emoji
                                } label: {
                                    cell(for: emoji)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, isMacLayout ? 24 : 16)
                        .padding(.top, isMacLayout ? 10 : 6)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle(isMacLayout ? "" : "Board Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isMacLayout {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { commitAndDismiss() }
                            .disabled(pendingIcon == currentIcon)
                    }
                }
            }
            .onAppear { pendingIcon = currentIcon }
        }
    }

    private var macSheetHeader: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 12)

            Text("Board Icon")
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 12)

            Button("Done") { commitAndDismiss() }
                .disabled(pendingIcon == currentIcon)
                .frame(width: 82, alignment: .trailing)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func commitAndDismiss() {
        if pendingIcon != currentIcon { onSelect(pendingIcon) }
        dismiss()
    }

    private func cell(for emoji: String) -> some View {
        let isSelected = emoji == pendingIcon
        return Text(emoji)
            .font(.system(size: 34))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.05), lineWidth: isSelected ? 1.4 : 0.5)
            )
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isSelected)
    }
}
