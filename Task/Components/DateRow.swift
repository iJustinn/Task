import SwiftUI

struct DateRow: View {
    let start: Date
    let end: Date?
    let tint: Color
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        HStack(spacing: 6) {
            Text(TaskDateFormat.formatRange(start, end, style: settings.dateFormat))
                .font(.footnote)
                .foregroundStyle(tint)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

struct DueDateRow: View {
    let date: Date
    let isUpcoming: Bool
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        let tint = isUpcoming ? ColorKey.blue.foreground : ColorKey.red.foreground
        HStack(spacing: 6) {
            Text(TaskDateFormat.format(date, style: settings.dateFormat))
                .font(.footnote)
                .foregroundStyle(tint)
            Spacer(minLength: 0)
        }
    }
}
