import SwiftUI
import SwiftData

struct TaskDetailView: View {
    enum Mode {
        case create(defaultGroup: BoardGroup?)
        case edit(TaskItem)
    }

    let board: Board
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedGroup: BoardGroup?
    @State private var selectedTags: [TaskTag] = []
    @State private var workingStart: Date? = nil
    @State private var workingEnd: Date? = nil
    @State private var dueDate: Date? = nil
    @State private var hasReminder: Bool = false
    @State private var repeatRule: RepeatRule = .none
    @State private var isWorkingRange: Bool = false
    @State private var didLoad: Bool = false

    @State private var showStatusPicker: Bool = false
    @State private var showTagPicker: Bool = false
    @State private var showWorkingPicker: Bool = false
    @State private var showDuePicker: Bool = false
    @State private var showRepeatPicker: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private enum ReminderAnchor { case working, due, none }

    private static let labelColumnWidth: CGFloat = 120

    private var editingTask: TaskItem? {
        if case .edit(let task) = mode { return task }
        return nil
    }

    private var isCreating: Bool { editingTask == nil }

    /// Mirrors `TaskItem.primaryReminderDate`: when both dates are set the
    /// notification fires for the earlier one, so the alarm icon sits on
    /// whichever row that is.
    private var reminderAnchor: ReminderAnchor {
        guard hasReminder else { return .none }
        switch (workingStart, dueDate) {
        case (nil, nil):    return .none
        case (_, nil):      return .working
        case (nil, _):      return .due
        case let (w?, d?):  return w <= d ? .working : .due
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            titleField
                            propertyList
                            Divider()
                            notesSection
                            if !isCreating {
                                Spacer(minLength: 24)
                                deleteButton
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                        .frame(minHeight: proxy.size.height, alignment: .topLeading)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle(isCreating ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isCreating ? "Add" : "Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedGroup == nil)
                }
            }
            .onAppear { load() }
            .onChange(of: workingStart) { _, _ in disableReminderIfNoDates() }
            .onChange(of: dueDate) { _, _ in disableReminderIfNoDates() }
            .onChange(of: hasReminder) { _, isOn in
                if isOn { Task { await requestNotificationPermissionIfNeeded() } }
            }
            .sheet(isPresented: $showStatusPicker) {
                StatusPickerSheet(board: board, selection: $selectedGroup)
                    .presentationDetents([.fraction(0.6), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTagPicker) {
                TagPickerSheet(board: board, selection: $selectedTags)
                    .presentationDetents([.fraction(0.6), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWorkingPicker) {
                workingDateSheet
                    .presentationDetents([.fraction(0.6), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showDuePicker) {
                dueDateSheet
                    .presentationDetents([.fraction(0.6), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showRepeatPicker) {
                RepeatPickerSheet(selection: $repeatRule)
                    .presentationDetents([.fraction(0.6), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showDeleteConfirm) {
                ConfirmationSheet(
                    icon: "trash.fill",
                    iconTint: .red,
                    title: "Delete Task?",
                    message: "This task and any reminder you set will be removed permanently.",
                    confirmLabel: "Delete Task"
                ) {
                    delete()
                }
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var titleField: some View {
        TextField("", text: $title, prompt: Text("Add title").foregroundStyle(.secondary), axis: .vertical)
            .font(.system(.largeTitle, design: .rounded))
            .fontWeight(.bold)
            .lineLimit(1...3)
            .textInputAutocapitalization(.words)
    }

    private var propertyList: some View {
        VStack(spacing: 14) {
            statusRow
            tagsRow
            workingDateRow
            dueDateRow
            repeatRow
            reminderRow
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            MarkdownNotesEditor(text: $notes)
        }
    }

    private var deleteButton: some View {
        Button { showDeleteConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(.subheadline, weight: .bold))
                Text("Delete Task")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Property rows

    private var statusRow: some View {
        Button { showStatusPicker = true } label: {
            propertyRow(icon: "circle.dotted", label: "Status") {
                if let group = selectedGroup {
                    HStack(spacing: 6) {
                        Circle().fill(group.colorKey.dot).frame(width: 9, height: 9)
                        Text(group.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(group.colorKey.foreground)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(group.colorKey.background))
                } else {
                    emptyValueLabel
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var tagsRow: some View {
        Button { showTagPicker = true } label: {
            propertyRow(icon: "tag", label: "Tags") {
                if selectedTags.isEmpty {
                    emptyValueLabel
                } else {
                    FlowLayout(spacing: 4, lineSpacing: 4) {
                        ForEach(selectedTags, id: \.id) { tag in
                            TagChip(name: tag.name, colorKey: tag.colorKey)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var workingDateRow: some View {
        Button { showWorkingPicker = true } label: {
            propertyRow(icon: "calendar", label: "Working") {
                if let start = workingStart {
                    let tint = dateTint(for: start)
                    HStack(alignment: .center, spacing: 8) {
                        Text(workingDateDisplay(start: start, end: workingEnd))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(tint)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if reminderAnchor == .working {
                            Image(systemName: "alarm")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                    }
                } else {
                    emptyValueLabel
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func workingDateDisplay(start: Date, end: Date?) -> String {
        guard isWorkingRange,
              let end,
              Calendar.current.startOfDay(for: end) != Calendar.current.startOfDay(for: start)
        else { return TaskDateFormat.format(start) }
        return "\(TaskDateFormat.format(start)) →\n\(TaskDateFormat.format(end))"
    }

    private var dueDateRow: some View {
        Button { showDuePicker = true } label: {
            propertyRow(icon: "calendar.badge.exclamationmark", label: "Due Date") {
                if let due = dueDate {
                    let tint = dateTint(for: due)
                    HStack(alignment: .center, spacing: 8) {
                        Text(TaskDateFormat.format(due))
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(tint)
                        Spacer(minLength: 8)
                        if reminderAnchor == .due {
                            Image(systemName: "alarm")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                    }
                } else {
                    emptyValueLabel
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var reminderRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            propertyRow(icon: "alarm", label: "Reminder", valueAlignment: .trailing) {
                Toggle("", isOn: $hasReminder)
                    .labelsHidden()
                    .disabled(workingStart == nil && dueDate == nil)
            }
            if hasReminder, settings.notificationsAuthorized == false {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("Notifications are off for Task. Enable them in iOS Settings or this reminder won't fire.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 32)
            }
        }
    }

    private var repeatRow: some View {
        // The whole row is tappable for consistency with Status / Tags / Working /
        // Due. The advance "→" chip lives outside the row's Button so it doesn't
        // open the picker when tapped.
        ZStack {
            Button { showRepeatPicker = true } label: {
                propertyRow(icon: "arrow.clockwise", label: "Repeat") {
                    HStack(spacing: 8) {
                        if repeatRule == .none {
                            emptyValueLabel
                        } else {
                            TagChip(name: repeatRule.displayName, colorKey: .gray)
                        }
                        Spacer(minLength: 0)
                        // Reserve trailing space so the chip never overlaps the
                        // advance button below.
                        if repeatRule != .none && (workingStart != nil || dueDate != nil) {
                            Color.clear.frame(width: 62, height: 30)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if repeatRule != .none && (workingStart != nil || dueDate != nil) {
                HStack {
                    Spacer()
                    Button { advanceRepeatDates() } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ColorKey.gray.foreground)
                            .frame(width: 62, height: 30)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ColorKey.gray.background)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Reset to next occurrence"))
                }
            }
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func propertyRow<Content: View>(
        icon: String,
        label: String,
        valueAlignment: Alignment = .leading,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: Self.labelColumnWidth, alignment: .leading)
            value()
                .frame(maxWidth: .infinity, alignment: valueAlignment)
        }
        .frame(minHeight: 42)
        .contentShape(Rectangle())
    }

    private var emptyValueLabel: some View {
        Text("Empty")
            .font(.system(.body, design: .rounded))
            .foregroundStyle(Color.secondary.opacity(0.6))
    }

    private func dateTint(for date: Date) -> Color {
        let today = Calendar.current.startOfDay(for: Date())
        let upcoming = Calendar.current.startOfDay(for: date) > today
        return upcoming ? ColorKey.blue.foreground : ColorKey.red.foreground
    }

    // MARK: - Date sheets

    private var workingDateSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        rangeToggleRow
                        Divider()
                        workingCalendar
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Working Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showWorkingPicker = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showWorkingPicker = false }
                }
            }
        }
    }

    @ViewBuilder
    private var workingCalendar: some View {
        if isWorkingRange {
            CalendarPicker(rangeStart: $workingStart, rangeEnd: $workingEnd)
        } else {
            CalendarPicker(selectedDate: $workingStart)
        }
    }

    private var dueDateSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        CalendarPicker(selectedDate: $dueDate)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showDuePicker = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showDuePicker = false }
                }
            }
        }
    }

    private var rangeToggleRow: some View {
        propertyRow(icon: "calendar.day.timeline.right", label: "End Date", valueAlignment: .trailing) {
            Toggle("", isOn: $isWorkingRange)
                .labelsHidden()
        }
        .onChange(of: isWorkingRange) { _, on in
            if !on { workingEnd = nil }
        }
    }

    // MARK: - Load / Save / Delete

    private func load() {
        guard !didLoad else { return }
        switch mode {
        case .create(let defaultGroup):
            selectedGroup = defaultGroup ?? board.orderedGroups.first
        case .edit(let task):
            title = task.title
            notes = task.notes
            selectedGroup = task.group
            selectedTags = task.tags ?? []
            workingStart = task.workingStart
            workingEnd = task.workingEnd
            dueDate = task.dueDate
            hasReminder = task.hasReminder
            repeatRule = task.repeatRule
            isWorkingRange = task.workingIsRange
        }
        didLoad = true
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let group = selectedGroup else { return }

        let task: TaskItem
        switch mode {
        case .create:
            let sortIndex = (group.orderedTasks.last?.sortIndex ?? -1) + 1
            task = TaskItem(title: trimmed, notes: notes, sortIndex: sortIndex)
            task.board = board
            task.group = group
            context.insert(task)
        case .edit(let existing):
            task = existing
            task.title = trimmed
            task.notes = notes
            if task.group !== group {
                task.group = group
                task.sortIndex = (group.orderedTasks.last?.sortIndex ?? -1) + 1
            }
        }

        task.tags = selectedTags
        task.workingStart = workingStart
        task.workingEnd = isWorkingRange ? workingEnd : nil
        task.dueDate = dueDate
        let intendsReminder = hasReminder && (workingStart != nil || dueDate != nil)
        // For non-repeating tasks, a fire date in the past would never deliver a
        // notification. Clear the flag so the card/editor don't show the alarm icon
        // for a reminder that won't fire.
        if intendsReminder, repeatRule == .none, let fire = candidateFireDate(), fire <= Date() {
            task.hasReminder = false
        } else {
            task.hasReminder = intendsReminder
        }
        task.repeatRule = repeatRule
        task.touch()

        try? context.save()

        if task.hasReminder {
            NotificationService.schedule(for: task)
        } else {
            NotificationService.cancel(for: task)
        }
        UpcomingSnapshotBuilder.writeSnapshot(from: context)

        dismiss()
    }

    /// Keep the Reminder toggle visibly in sync with whether any date is set, so
    /// `save()` never has to silently strip a reminder the user thinks is on.
    private func disableReminderIfNoDates() {
        if workingStart == nil && dueDate == nil && hasReminder {
            hasReminder = false
        }
    }

    /// Request notification permission lazily — only when the user actually opts in
    /// to a reminder. This matches the privacy copy ("Task asks for notification
    /// permission only to deliver local reminders you opt into per task") and keeps
    /// the system prompt from interrupting first-launch onboarding.
    private func requestNotificationPermissionIfNeeded() async {
        await NotificationService.requestAuthorizationIfNeeded()
        await settings.refreshNotificationAuthorization()
    }

    /// Mirrors `TaskItem.primaryReminderDate` against the editor's local @State so
    /// the save path can predict whether a non-repeating reminder would fire in the
    /// past (and therefore should not flip `hasReminder` to true on disk). Time of
    /// day comes from the board's reminder setting when the picked date is midnight.
    private func candidateFireDate() -> Date? {
        let anchor: Date?
        if let w = workingStart, let d = dueDate {
            anchor = min(w, d)
        } else {
            anchor = dueDate ?? (isWorkingRange ? workingEnd : nil) ?? workingStart
        }
        guard let anchor else { return nil }
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: anchor)
        if comps.hour == 0 && comps.minute == 0 {
            let minutes = board.reminderMinutesOfDay
            comps.hour = minutes / 60
            comps.minute = minutes % 60
        }
        return Calendar.current.date(from: comps)
    }

    /// Shift every set date (workingStart, workingEnd, dueDate) forward by one occurrence
    /// of the current rule so the relative window is preserved. No-op when no dates exist.
    private func advanceRepeatDates() {
        guard repeatRule != .none, workingStart != nil || dueDate != nil else { return }
        workingStart = workingStart.map { repeatRule.advance($0) }
        workingEnd = workingEnd.map { repeatRule.advance($0) }
        dueDate = dueDate.map { repeatRule.advance($0) }
    }

    private func delete() {
        guard let task = editingTask else { return }
        NotificationService.cancel(for: task)
        context.delete(task)
        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        dismiss()
    }
}
