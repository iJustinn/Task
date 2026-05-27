import SwiftUI

struct SettingsCardSection<Content: View>: View {
    let title: LocalizedStringKey?
    private let content: Content

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(PlatformLayout.prefersMacInterface ? .title3 : .title).weight(.bold))
                    .foregroundColor(.primary)
            }
            VStack(spacing: 0) {
                content
            }
            .background {
                if PlatformLayout.prefersMacInterface {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PlatformLayout.prefersMacInterface ? 8 : 0, style: .continuous))
            .overlay {
                if PlatformLayout.prefersMacInterface {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
            }
        }
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, PlatformLayout.prefersMacInterface ? 54 : 8)
            .padding(.trailing, 8)
    }
}

struct SettingsIconTile: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: PlatformLayout.prefersMacInterface ? 17 : 21, weight: .semibold))
            .foregroundColor(color)
            .frame(
                width: PlatformLayout.prefersMacInterface ? 32 : 44,
                height: PlatformLayout.prefersMacInterface ? 32 : 44
            )
    }
}

enum SettingsRowAccessory {
    case none
    case chevron
    case toggle(isOn: Binding<Bool>)
}

struct SettingsRowLabel: View {
    let title: LocalizedStringKey
    /// Pre-resolved text — typically a dynamic value (app version, user choice
    /// label). Static literals should be wrapped with `String(localized:)` at
    /// the callsite so they translate.
    var value: String? = nil
    let systemName: String
    let tintColor: Color
    var accessory: SettingsRowAccessory = .none
    var dimmed: Bool = false

    var body: some View {
        HStack(spacing: PlatformLayout.prefersMacInterface ? 12 : 14) {
            SettingsIconTile(systemName: systemName, color: tintColor)

            Text(title)
                .font(.system(PlatformLayout.prefersMacInterface ? .body : .headline))
                .fontWeight(.semibold)
                .foregroundColor(dimmed ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 12)

            if let value {
                Text(value)
                    .font(.system(.subheadline))
                    .fontWeight(.regular)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.trailing)
            }

            accessoryView
        }
        .padding(.horizontal, PlatformLayout.prefersMacInterface ? 10 : 8)
        .padding(.vertical, PlatformLayout.prefersMacInterface ? 7 : 14)
        .frame(maxWidth: .infinity, minHeight: PlatformLayout.prefersMacInterface ? 46 : 70, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.secondary.opacity(0.7))
        case .toggle(let isOn):
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }
}

struct SettingsButtonRow<Trailing: View>: View {
    let title: LocalizedStringKey
    let systemName: String
    let tintColor: Color
    let action: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        Button(action: action) {
            HStack(spacing: PlatformLayout.prefersMacInterface ? 12 : 14) {
                SettingsIconTile(systemName: systemName, color: tintColor)
                Text(title)
                    .font(.system(PlatformLayout.prefersMacInterface ? .body : .headline))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.horizontal, PlatformLayout.prefersMacInterface ? 10 : 8)
            .padding(.vertical, PlatformLayout.prefersMacInterface ? 7 : 14)
            .frame(maxWidth: .infinity, minHeight: PlatformLayout.prefersMacInterface ? 46 : 70, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SheetActionButtonLabel: View {
    let title: LocalizedStringKey
    let systemName: String
    let tintColor: Color
    var fillsWidth: Bool = false

    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        HStack(spacing: settings.textSize.sheetActionSpacing) {
            Image(systemName: systemName)
                .font(.system(size: settings.textSize.sheetActionIconSize, weight: .bold))
            Text(title)
                .font(.system(size: settings.textSize.sheetActionTextSize, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(tintColor)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private extension AppTextSize {
    var sheetActionTextSize: CGFloat {
        switch self {
        case .small:      return 15.5
        case .medium:     return 16.5
        case .large:      return 17.5
        case .extraLarge: return 18.5
        }
    }

    var sheetActionIconSize: CGFloat {
        switch self {
        case .small:      return 13.5
        case .medium:     return 14.5
        case .large:      return 15.5
        case .extraLarge: return 16.5
        }
    }

    var sheetActionSpacing: CGFloat {
        switch self {
        case .small:      return 7
        case .medium:     return 7
        case .large:      return 8
        case .extraLarge: return 8
        }
    }
}
