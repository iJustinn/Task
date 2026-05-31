import SwiftUI
import UIKit

// MARK: - Shared models / sections

struct AboutInfoSection: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let systemImage: String
    let tintColor: Color
    let details: [LocalizedStringKey]
}

struct AboutGuideSection: Identifiable {
    let id = UUID()
    let title: LocalizedStringKey
    let systemImage: String
    let tintColor: Color
    let steps: [LocalizedStringKey]
}

private struct AboutSectionDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 8)
            .padding(.trailing, 8)
    }
}

private enum AboutBulletStyle {
    static let leadingIndent: CGFloat = 32
    static let markerSlotWidth: CGFloat = 14
    static let markerSize: CGFloat = 6
}

struct AboutInfoCard: View {
    let section: AboutInfoSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SettingsIconTile(systemName: section.systemImage, color: section.tintColor)
                Text(section.title)
                    .font(.system(.headline).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.details.indices, id: \.self) { index in
                    let detail = section.details[index]
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(section.tintColor.opacity(0.72))
                            .frame(width: AboutBulletStyle.markerSize, height: AboutBulletStyle.markerSize)
                            .padding(.top, 7)
                            .frame(width: AboutBulletStyle.markerSlotWidth, alignment: .leading)
                        Text(detail)
                            .font(.system(.subheadline).weight(.semibold))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.leading, AboutBulletStyle.leadingIndent)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AboutGuideCard: View {
    let section: AboutGuideSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                SettingsIconTile(systemName: section.systemImage, color: section.tintColor)
                Text(section.title)
                    .font(.system(.headline).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.steps.indices, id: \.self) { index in
                    let step = section.steps[index]
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(section.tintColor.opacity(0.72))
                            .frame(width: AboutBulletStyle.markerSize, height: AboutBulletStyle.markerSize)
                            .padding(.top, 7)
                            .frame(width: AboutBulletStyle.markerSlotWidth, alignment: .leading)
                        Text(step)
                            .font(.system(.subheadline).weight(.semibold))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.leading, AboutBulletStyle.leadingIndent)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - How to Use

struct HowToUseSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [AboutGuideSection] = [
        AboutGuideSection(
            title: "Boards",
            systemImage: "archivebox.fill",
            tintColor: .accentColor,
            steps: [
                "Tap the archive button in the bottom bar to open the board switcher. Fresh installs ship with three boards — Personal, Study, and Work — each with their own groups, tags, and tasks.",
                "Tap Add in the switcher to create a new board with placeholder text — then tap the title, subtitle, or icon on the board header to edit them in place.",
                "Long-press a board row to drag-reorder it. Expand the switcher and tap Delete a Board to choose a board for deletion with a confirmation popup. Disabled when only one board remains."
            ]
        ),
        AboutGuideSection(
            title: "Create Tasks",
            systemImage: "plus.circle.fill",
            tintColor: .blue,
            steps: [
                "Tap + in the bottom bar to start a new task and type a title.",
                "New tasks open in the board's Default Status. Open a status column's ··· menu and enable Default for New Tasks to change where new tasks land.",
                "Toggle Checkbox in a task to show a box before the card title. Tap the box on the card to mark the task done or not done without moving it to another status.",
                "Toggle Reminder to schedule a local notification. A small footer on the card shows a notes icon when the task has notes and an alarm icon when a reminder is set."
            ]
        ),
        AboutGuideSection(
            title: "Notes & Checklists",
            systemImage: "checklist",
            tintColor: .green,
            steps: [
                "Tap the Notes area on a task to type. Markdown is supported — **bold**, *italic*, # heading, and - bullet lines all render once you tap away.",
                "Add a checkbox by starting a line with [] for unchecked, or [x] for checked. Tap a box in the rendered preview to toggle it — the note rewrites in place.",
                "Tap any rendered line to jump back into edit mode and adjust the raw markdown. Drag the sheet down to dismiss the keyboard and return to the preview."
            ]
        ),
        AboutGuideSection(
            title: "Organize the Board",
            systemImage: "rectangle.3.group.fill",
            tintColor: .pink,
            steps: [
                "Long-press a task card to lift it, then drag up/down within a column to reorder, or sideways onto another column to change its status.",
                "Long-press a group's colored pill header and drag it onto another column's header to swap their positions.",
                "Pull a column down to refresh — it resets that status's card limit and re-renders the column."
            ]
        ),
        AboutGuideSection(
            title: "Tags & Groups",
            systemImage: "tag.fill",
            tintColor: .orange,
            steps: [
                "Tap a group's ··· menu on the board to rename, recolor, or delete it. Inside a task, tap Status to add a new group, drag-reorder rows, or expand the sheet and use Delete a Status.",
                "Inside a task, tap Tags to choose or create tags scoped to the active board. Long-press a row to drag-reorder, or expand the sheet and use Delete a Tag to remove it from every task on the board.",
                "Two boards can each have their own group called \"Doing\" — groups and tags don't cross boards."
            ]
        ),
        AboutGuideSection(
            title: "Dates & Reminders",
            systemImage: "calendar.badge.clock",
            tintColor: .red,
            steps: [
                "Tap a day on the calendar to set the date; tap it again to clear.",
                "Enable End Date in the Working date sheet to select a range — the strip between the two days highlights blue.",
                "Dates show blue on cards when the date is still in the future, and red once it has arrived or passed. Reminders fire at the time you set per-board — open Settings > Board > Reminder Time to change it.",
                "When a task has both a working date and a due date, the reminder fires on whichever comes first. For a working range with no due date, the reminder fires on the first day of the range."
            ]
        ),
        AboutGuideSection(
            title: "Search",
            systemImage: "magnifyingglass.circle.fill",
            tintColor: .indigo,
            steps: [
                "Tap the search field in the bottom bar; the bar transforms and the keyboard appears.",
                "Type any text — Task searches titles, notes, tag names, and group names live.",
                "Tap X on the bar to clear the query and return to the board."
            ]
        ),
        AboutGuideSection(
            title: "Defaults",
            systemImage: "slider.horizontal.3",
            tintColor: .teal,
            steps: [
                "Settings > Board to switch Date Filter, Date Format, Notes Preview, Status Width, Search Mode, and Reminder Time.",
                "The board header keeps quick controls for Card Order and the date filter. Default Status now lives in each status column's ··· menu.",
                "Default Status sets which group new tasks on that board land in. Falls back to the first group if your choice is later deleted. Card Order controls how cards sort inside every group on that board — Manual (drag), Title (alphabetical), or Date (smart).",
                "Status Width controls how wide each status column on the board is — Small (180), Medium (200), or Large (220).",
                "Search Mode chooses whether search opens a global results list or filters cards on the current board.",
                "Reminder Time sets the hour and minute (defaults to 9:00) that this board's per-task reminders fire on the chosen date."
            ]
        ),
        AboutGuideSection(
            title: "Appearance",
            systemImage: "slider.horizontal.3",
            tintColor: .purple,
            steps: [
                "Settings > Appearance to switch Theme, Language, Text Size, App Accent, and App Icon.",
                "Text Size scales fonts across the whole app while respecting Dynamic Type."
            ]
        ),
        AboutGuideSection(
            title: "Data",
            systemImage: "externaldrive.fill",
            tintColor: .gray,
            steps: [
                "Settings > Data > Manual Control to Export every board as a single JSON file or Import a previously exported file. Older single-board exports also import cleanly.",
                "Reset All Data wipes every board and re-seeds the three defaults (Personal, Study, Work) with the standard five groups.",
                "iCloud Sync is on the roadmap — the schema is already CloudKit-compatible."
            ]
        ),
        AboutGuideSection(
            title: "Widget",
            systemImage: "apps.iphone",
            tintColor: .accentColor,
            steps: [
                "Add the Upcoming Tasks widget from the iOS widget gallery in Small, Medium, or Large.",
                "Long-press the widget and tap Edit Widget to choose a specific board — or leave Board empty to show upcoming tasks from every board.",
                "When All Boards is selected, each row shows the board's emoji so you can tell them apart at a glance."
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sections.indices), id: \.self) { index in
                            AboutGuideCard(section: sections[index])
                            if index < sections.count - 1 {
                                AboutSectionDivider()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Feedback

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let supportEmail = "zihengthedeveloper@gmail.com"

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    SettingsCardSection {
                        Button {
                            openSupportEmail()
                        } label: {
                            SettingsRowLabel(
                                title: "Email",
                                value: supportEmail,
                                systemName: "envelope.fill",
                                tintColor: .blue,
                                accessory: .chevron
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func openSupportEmail() {
        guard let url = supportEmailURL else { return }
        openURL(url)
    }

    private var supportEmailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Task Feedback"),
            URLQueryItem(name: "body", value: feedbackBody)
        ]
        return components.url
    }

    private var feedbackBody: String {
        let device = UIDevice.current
        return """


        ---
        App: Task
        Version: \(AppInfo.versionAndBuild)
        Device: \(device.model)
        System: \(device.systemName) \(device.systemVersion)
        Locale: \(Locale.current.identifier)
        Time Zone: \(TimeZone.current.identifier)
        """
    }
}

// MARK: - Privacy

struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [AboutInfoSection] = [
        AboutInfoSection(
            title: "Local-First Data",
            systemImage: "iphone",
            tintColor: .green,
            details: [
                "All boards, groups, tags, tasks, notes, and preferences are stored on this device via SwiftData.",
                "The widget reads a small JSON snapshot of upcoming tasks from the App Group container shared with the main app.",
                "Task does not bundle advertising, analytics, or tracking SDKs."
            ]
        ),
        AboutInfoSection(
            title: "Network Access",
            systemImage: "network",
            tintColor: .blue,
            details: [
                "Task does not make any network requests on its own.",
                "If you choose Feedback, your email app prepares a message containing app version, device, system, locale, and time zone details — you review and send it yourself."
            ]
        ),
        AboutInfoSection(
            title: "Notifications",
            systemImage: "bell.badge.fill",
            tintColor: .red,
            details: [
                "Task asks for notification permission only to deliver local reminders you opt into per task.",
                "Reminders are scheduled with UNUserNotificationCenter on this device. Nothing is sent off-device.",
                "Removing a task or turning its Reminder off cancels the scheduled notification."
            ]
        ),
        AboutInfoSection(
            title: "Your Control",
            systemImage: "externaldrive.fill",
            tintColor: .orange,
            details: [
                "Settings > Data > Manual Control lets you export your data as JSON or import a previous backup.",
                "Reset All Data wipes every group, tag, and task from local storage and reseeds the default groups."
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sections.indices), id: \.self) { index in
                            AboutInfoCard(section: sections[index])
                            if index < sections.count - 1 {
                                AboutSectionDivider()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Disclaimer

struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let section = AboutInfoSection(
        title: "Disclaimer",
        systemImage: "exclamationmark.triangle.fill",
        tintColor: .yellow,
        details: [
            "Task is a personal productivity app for tracking your own tasks and reminders.",
            "Task does not provide professional advice, project management guarantees, or compliance services.",
            "Local notifications depend on your device permissions and iOS scheduling; if a reminder is critical, also confirm it with the system Calendar or Reminders app."
        ]
    )

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    AboutInfoCard(section: section)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Copyright

struct CopyrightSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                SettingsIconTile(systemName: "c.circle.fill", color: .purple)
                                Text("Copyright")
                                    .font(.system(.headline).weight(.bold))
                                    .foregroundColor(.primary)
                            }
                            Text("© 2026 iJustin. All rights reserved.")
                                .font(.system(.headline).weight(.semibold))
                                .foregroundColor(.primary)
                            Text("Task is a personal productivity app inspired by Notion's Kanban view. Design language adapted from Coin and Body.")
                                .font(.system(.subheadline).weight(.semibold))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Copyright")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
