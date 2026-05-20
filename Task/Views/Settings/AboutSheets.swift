import SwiftUI
import UIKit

// MARK: - Shared models / cards

struct AboutInfoSection: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tintColor: Color
    let details: [String]
}

struct AboutGuideSection: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tintColor: Color
    let steps: [String]
}

struct AboutInfoCard: View {
    let section: AboutInfoSection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                SettingsIconTile(systemName: section.systemImage, color: section.tintColor)
                Text(section.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(section.details, id: \.self) { detail in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(section.tintColor.opacity(0.72))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(detail)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .taskCardBackground()
    }
}

struct AboutGuideCard: View {
    let section: AboutGuideSection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                SettingsIconTile(systemName: section.systemImage, color: section.tintColor)
                Text(section.title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(section.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(section.tintColor)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(section.tintColor.opacity(0.14)))
                        Text(step)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .taskCardBackground()
    }
}

// MARK: - How to Use

struct HowToUseSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [AboutGuideSection] = [
        AboutGuideSection(
            title: "Create Tasks",
            systemImage: "plus.circle.fill",
            tintColor: .blue,
            steps: [
                "Tap + in the bottom bar to start a new task and type a title.",
                "New tasks open in your default Status (Settings > Default > Status) — pick a different group, add Tags, and set a Working date or Due date.",
                "Toggle Reminder to schedule a local notification. A small footer on the card shows a notes icon when the task has notes and an alarm icon when a reminder is set."
            ]
        ),
        AboutGuideSection(
            title: "Notes & Checklists",
            systemImage: "checklist",
            tintColor: .green,
            steps: [
                "Tap the Notes area on a task to type. Markdown is supported — **bold**, *italic*, # heading, and - bullet lines all render once you tap away.",
                "Add a checkbox by starting a line with - [ ] (or - []) for unchecked, or - [x] for checked. Tap a box in the rendered preview to toggle it — the note rewrites in place.",
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
                "Pull a column down to refresh — it resets the Top 10 view and re-renders that column."
            ]
        ),
        AboutGuideSection(
            title: "Tags & Groups",
            systemImage: "tag.fill",
            tintColor: .orange,
            steps: [
                "Settings > Customization > Groups to add, rename, recolor, long-press drag-reorder, or delete groups.",
                "Settings > Customization > Tags to create tags with a custom color, long-press drag-reorder, or delete one to remove it from every task.",
                "Tap a group's ··· menu on the board for quick rename / recolor / delete."
            ]
        ),
        AboutGuideSection(
            title: "Dates & Reminders",
            systemImage: "calendar.badge.clock",
            tintColor: .red,
            steps: [
                "Tap a day on the calendar to set the date; tap it again to clear.",
                "Enable End Date in the Working date sheet to select a range — the strip between the two days highlights blue.",
                "Dates show blue on cards when the date is still in the future, and red once it has arrived or passed. Reminders fire at the time you set in Settings > Default > Reminder Time."
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
            systemImage: "flag.fill",
            tintColor: .teal,
            steps: [
                "Settings > Default > Status sets which group new tasks land in. Falls back to the first group if your choice is later deleted.",
                "Settings > Default > Card Order controls how cards sort inside every group — Manual (drag), Title (alphabetical), or Date (smart) — with Ascending / Descending for Title and Date.",
                "Settings > Default > Reminder Time sets the hour and minute (defaults to 9:00) that per-task reminders fire on the chosen date."
            ]
        ),
        AboutGuideSection(
            title: "Appearance",
            systemImage: "slider.horizontal.3",
            tintColor: .purple,
            steps: [
                "Settings > Appearance to switch Theme, Language, Time Format (System / 12-hour / 24-hour), Text Size, Group Width, App Accent, and App Icon.",
                "Group Width controls how wide each column on the board is — Small (180), Medium (200), or Large (220).",
                "Text Size scales fonts across the whole app while respecting Dynamic Type."
            ]
        ),
        AboutGuideSection(
            title: "Data",
            systemImage: "externaldrive.fill",
            tintColor: .gray,
            steps: [
                "Settings > Data > Manual Control to Export your board as a JSON file or Import a previously exported file.",
                "Reset All Data deletes every task, tag, and group, then re-creates the six default groups.",
                "iCloud Sync is on the roadmap — your schema is already CloudKit-compatible."
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(sections) { section in
                            AboutGuideCard(section: section)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("How to Use")
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
}

// MARK: - Feedback

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let supportEmail = "zihengthedeveloper@gmail.com"

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
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
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
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
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(sections) { section in
                            AboutInfoCard(section: section)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Privacy")
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
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    AboutInfoCard(section: section)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 30)
                }
            }
            .navigationTitle("Disclaimer")
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
}

// MARK: - Copyright

struct CopyrightSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                SettingsIconTile(systemName: "c.circle.fill", color: .purple)
                                Text("Copyright")
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundColor(.primary)
                            }
                            Text("© 2026 iJustin. All rights reserved.")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundColor(.primary)
                            Text("Task is a personal productivity app inspired by Notion's Kanban view. Design language adapted from Coin and Body.")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .taskCardBackground()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Copyright")
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
}
