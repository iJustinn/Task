import SwiftUI
import UIKit

struct BottomNavBar: View {
    @Binding var searchText: String
    var onAdd: () -> Void
    var onSettings: () -> Void
    var onFocusChange: ((Bool) -> Void)? = nil

    @FocusState private var fieldFocused: Bool
    private let barHeight: CGFloat = 50

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                liquidGlassBar
            } else {
                legacyBar
            }
        }
        .onChange(of: fieldFocused) { _, focused in
            onFocusChange?(focused)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: fieldFocused)
    }

    // MARK: - iOS 26 Liquid Glass

    @available(iOS 26.0, *)
    private var liquidGlassBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                if !fieldFocused {
                    glassCircleButton(systemName: "plus", weight: .semibold, action: onAdd, label: "Add task")
                        .transition(.scale.combined(with: .opacity))
                }

                searchField
                    .frame(height: barHeight)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: Capsule())

                if fieldFocused {
                    glassCircleButton(systemName: "xmark", weight: .semibold, action: cancelSearch, label: "Cancel search")
                        .transition(.scale.combined(with: .opacity))
                } else {
                    glassCircleButton(systemName: "gearshape", weight: .medium, action: onSettings, label: "Settings")
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @available(iOS 26.0, *)
    private func glassCircleButton(systemName: String, weight: Font.Weight, action: @escaping () -> Void, label: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(weight))
                .foregroundStyle(.tint)
                .frame(width: barHeight, height: barHeight)
        }
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }

    // MARK: - iOS 18-25 fallback

    private var legacyBar: some View {
        HStack(spacing: 10) {
            if !fieldFocused {
                legacyCircleButton(systemName: "plus", weight: .semibold, action: onAdd, label: "Add task")
                    .transition(.scale.combined(with: .opacity))
            }

            searchField
                .frame(height: barHeight)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(Color(uiColor: .secondarySystemBackground)))

            if fieldFocused {
                legacyCircleButton(systemName: "xmark", weight: .semibold, action: cancelSearch, label: "Cancel search")
                    .transition(.scale.combined(with: .opacity))
            } else {
                legacyCircleButton(systemName: "gearshape", weight: .medium, action: onSettings, label: "Settings")
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private func legacyCircleButton(systemName: String, weight: Font.Weight, action: @escaping () -> Void, label: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(weight))
                .foregroundStyle(.primary)
                .frame(width: barHeight, height: barHeight)
                .background(Circle().fill(Color(uiColor: .secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Shared search field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Search", text: $searchText)
                .font(.subheadline)
                .submitLabel(.search)
                .focused($fieldFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func cancelSearch() {
        searchText = ""
        fieldFocused = false
    }
}
