import SwiftUI

struct RepeatPickerSheet: View {
    let board: Board
    @Binding var selection: RepeatRule
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel

    private let options: [RepeatRule] = [.daily, .weekly, .biweekly, .monthly, .quarterly, .annually]

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
                TagChip(name: rule.displayName, colorKey: .gray)

                Text("\(taskCount(for: rule)) tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                if selection == rule {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.accent)
                }
            }
            .padding(.vertical, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func taskCount(for rule: RepeatRule) -> Int {
        (board.tasks ?? []).filter { $0.repeatRule == rule }.count
    }
}
