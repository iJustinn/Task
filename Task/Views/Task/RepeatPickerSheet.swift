import SwiftUI

struct RepeatPickerSheet: View {
    let board: Board
    @Binding var selection: RepeatRule
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel

    private let options: [RepeatRule] = [.daily, .weekly, .biweekly, .monthly, .quarterly, .annually]
    private var isMacLayout: Bool { PlatformLayout.prefersMacInterface }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Color(isMacLayout ? .systemGroupedBackground : .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if isMacLayout {
                        macSheetHeader
                    }

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
                        .padding(.horizontal, isMacLayout ? 24 : 20)
                        .padding(.top, isMacLayout ? 10 : 8)
                        .padding(.bottom, isMacLayout ? 28 : 24)
                        .frame(minHeight: proxy.size.height - (isMacLayout ? 62 : 0), alignment: .topLeading)
                    }
                }
            }
            .navigationTitle(isMacLayout ? "" : "Choose Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isMacLayout {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
        .taskMacSheetFrame(width: 540, minHeight: 430)
    }

    private var macSheetHeader: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 12)

            Text("Choose Repeat")
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 12)

            Button("Done") { dismiss() }
                .frame(width: 82, alignment: .trailing)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func repeatRow(_ rule: RepeatRule) -> some View {
        Button {
            selection = (selection == rule) ? .none : rule
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                TagChip(name: rule.displayName, colorKey: .gray)

                Text("^[\(taskCount(for: rule)) task](inflect: true)")
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
