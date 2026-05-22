import SwiftUI

struct RepeatPickerSheet: View {
    @Binding var selection: RepeatRule
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel

    private let options: [RepeatRule] = [.daily, .weekly, .monthly]

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(options.enumerated()), id: \.element.id) { index, rule in
                                repeatRow(rule)
                                if index < options.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
                }
            }
            .navigationTitle("Choose Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    private func repeatRow(_ rule: RepeatRule) -> some View {
        Button {
            selection = (selection == rule) ? .none : rule
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon(for: rule))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ColorKey.gray.foreground)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 5) {
                    Text(rule.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 12)

                if selection == rule {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.accent)
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func icon(for rule: RepeatRule) -> String {
        switch rule {
        case .daily:   return "1.circle"
        case .weekly:  return "7.circle"
        case .monthly: return "calendar"
        case .none:    return "arrow.clockwise"
        }
    }
}
