import SwiftUI

struct ConfirmationSheet: View {
    let icon: String
    let iconTint: Color
    let title: String
    let message: String
    var confirmLabel: String = "Delete"
    var cancelLabel: String = "Cancel"
    var isDestructive: Bool = true
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(iconTint)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(iconTint.opacity(0.14))
                    )

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.system(.body))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button(role: isDestructive ? .destructive : nil) {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 180_000_000)
                            onConfirm()
                        }
                    } label: {
                        Text(confirmLabel)
                            .font(.system(.headline).weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isDestructive ? Color.red : Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text(cancelLabel)
                            .font(.system(.headline).weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.primary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .dynamicTypeSize(settings.textSize.dynamicType)
    }
}

extension View {
    func confirmationSheetPresentationStyle() -> some View {
        presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
    }
}
