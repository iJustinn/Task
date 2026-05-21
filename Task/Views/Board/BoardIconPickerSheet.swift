import SwiftUI

struct BoardIconPickerSheet: View {
    let currentIcon: String
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var pendingIcon: String = ""

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
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Board Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if pendingIcon != currentIcon { onSelect(pendingIcon) }
                        dismiss()
                    }
                    .disabled(pendingIcon == currentIcon)
                }
            }
            .onAppear { pendingIcon = currentIcon }
        }
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
