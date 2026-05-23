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
    @State private var showDuplicateConfirm: Bool = false

    private enum ReminderAnchor { case working, due, none }

    private static let labelColumnWidth: CGFloat = 120
    private static let taskTitleFontSize: CGFloat = 24
    private static let propertyFontSize: CGFloat = 16
    private static let chipFontSize: CGFloat = 16

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
                                bottomActionRow
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
                    .presentationDetents([.fraction(0.7), .large])
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
                .confirmationSheetPresentationStyle()
            }
            .sheet(isPresented: $showDuplicateConfirm) {
                ConfirmationSheet(
                    icon: "doc.on.doc.fill",
                    iconTint: .blue,
                    title: "Duplicate Task?",
                    message: "A copy of this task will be created in the same status.",
                    confirmLabel: "Duplicate Task",
                    isDestructive: false
                ) {
                    duplicate()
                }
                .confirmationSheetPresentationStyle()
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .presentationDragIndicator(.visible)
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    // MARK: - Sections

    private var titleField: some View {
        TextField("", text: $title, prompt: Text("Add title").foregroundStyle(.secondary), axis: .vertical)
            .font(.system(size: Self.taskTitleFontSize, weight: .bold, design: .rounded))
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

    private var bottomActionRow: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 34) {
                deleteButton
                duplicateButton
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
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
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var duplicateButton: some View {
        Button { showDuplicateConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc")
                    .font(.system(.subheadline, weight: .bold))
                Text("Duplicate Task")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.accent)
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
                    taskDetailChip(name: group.name, colorKey: group.colorKey)
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
                            taskDetailChip(name: tag.name, colorKey: tag.colorKey)
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
                            .font(.system(size: Self.propertyFontSize, weight: .semibold, design: .rounded))
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
        let style = settings.dateFormat
        guard isWorkingRange,
              let end,
              Calendar.current.startOfDay(for: end) != Calendar.current.startOfDay(for: start)
        else { return TaskDateFormat.format(start, style: style) }
        return "\(TaskDateFormat.format(start, style: style)) →\n\(TaskDateFormat.format(end, style: style))"
    }

    private var dueDateRow: some View {
        Button { showDuePicker = true } label: {
            propertyRow(icon: "calendar.badge.exclamationmark", label: "Due Date") {
                if let due = dueDate {
                    let tint = dateTint(for: due)
                    HStack(alignment: .center, spacing: 8) {
                        Text(TaskDateFormat.format(due, style: settings.dateFormat))
                            .font(.system(size: Self.propertyFontSize, weight: .semibold, design: .rounded))
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
                            taskDetailChip(name: repeatRule.displayName, colorKey: .gray)
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
                .font(.system(size: Self.propertyFontSize, weight: .medium, design: .rounded))
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
            .font(.system(size: Self.propertyFontSize, weight: .regular, design: .rounded))
            .foregroundStyle(Color.secondary.opacity(0.6))
    }

    private func taskDetailChip(name: String, colorKey: ColorKey) -> some View {
        Text(name)
            .font(.system(size: Self.chipFontSize, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(colorKey.foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(colorKey.background)
            )
            .fixedSize(horizontal: true, vertical: false)
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
        let isNewTask: Bool
        switch mode {
        case .create:
            let sortIndex = (group.orderedTasks.last?.sortIndex ?? -1) + 1
            task = TaskItem(title: trimmed, notes: notes, sortIndex: sortIndex)
            task.board = board
            task.group = group
            context.insert(task)
            isNewTask = true
        case .edit(let existing):
            task = existing
            task.title = trimmed
            task.notes = notes
            if task.group !== group {
                task.group = group
                task.sortIndex = (group.orderedTasks.last?.sortIndex ?? -1) + 1
            }
            isNewTask = false
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

        do {
            try context.save()
        } catch {
            // Save failed — don't schedule/cancel notifications or update the widget
            // for state that didn't commit. Drop the new task from the context so a
            // later unrelated save doesn't persist a half-built orphan.
            if isNewTask { context.delete(task) }
            dismiss()
            return
        }

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
            anchor = dueDate ?? workingStart ?? workingEnd
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

    private func duplicate() {
        guard let task = editingTask else { return }
        let group = task.group ?? selectedGroup
        let insertSortIndex = task.sortIndex + 1

        if let group {
            for sibling in group.orderedTasks where sibling.id != task.id && sibling.sortIndex >= insertSortIndex {
                sibling.sortIndex += 1
            }
        }

        let copy = task.duplicated(sortIndex: insertSortIndex)
        copy.board = task.board ?? board
        copy.group = group
        context.insert(copy)

        do {
            try context.save()
        } catch {
            context.rollback()
            dismiss()
            return
        }

        if copy.hasReminder {
            NotificationService.schedule(for: copy)
        }
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        dismiss()
    }

    private func delete() {
        guard let task = editingTask else { return }
        context.delete(task)
        do {
            try context.save()
        } catch {
            // The task is still in the store. Roll back the pending delete and skip
            // notification cancel + widget refresh so the UI stays consistent with
            // disk.
            context.rollback()
            dismiss()
            return
        }
        // Only cancel the reminder once the delete is durable — otherwise a failed
        // save would leave the task on disk with its scheduled notification gone.
        NotificationService.cancel(for: task)
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        dismiss()
    }
}
