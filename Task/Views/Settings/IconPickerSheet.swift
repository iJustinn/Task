import SwiftUI

struct IconPickerSheet: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
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
                                ForEach(Array(AppIconOption.allCases.enumerated()), id: \.element.id) { index, option in
                                    optionRow(option)
                                    if index < AppIconOption.allCases.count - 1 {
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
            .navigationTitle(isMacLayout ? "" : "App Icon")
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
        .taskMacSheetFrame(width: 560, minHeight: 460)
    }

    private var macSheetHeader: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .frame(width: 82, alignment: .leading)

            Spacer(minLength: 12)

            Text("App Icon")
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

    private func optionRow(_ option: AppIconOption) -> some View {
        Button {
            settings.appIcon = option
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(option.previewAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 5) {
                    Text(option.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(option.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if settings.appIcon == option {
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
}
