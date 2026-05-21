import SwiftUI

struct RepeatPickerSheet: View {
    @Binding var selection: RepeatRule
    @Environment(\.dismiss) private var dismiss

    private let options: [RepeatRule] = [.daily, .weekly, .monthly]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(options) { rule in
                            Button {
                                selection = (selection == rule) ? .none : rule
                                dismiss()
                            } label: {
                                GridTile(
                                    title: rule.displayName,
                                    systemImage: icon(for: rule),
                                    tintColor: ColorKey.gray.foreground,
                                    isSelected: selection == rule
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
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
