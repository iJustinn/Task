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
    @State private var showsCheckbox: Bool = false
    @State private var isChecked: Bool = false
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
    @State private var saveErrorMessage: String?

    private enum ReminderAnchor { case working, due, none }

    private var editingTask: TaskItem? {
        if case .edit(let task) = mode { return task }
        return nil
    }

    private var isCreating: Bool { editingTask == nil }

    private var sheetTitle: LocalizedStringKey {
        isCreating ? "New Task" : "Edit Task"
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && selectedGroup != nil
    }

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

    private var isMacLayout: Bool {
        PlatformLayout.prefersMacInterface
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    detailBackground.ignoresSafeArea()
                    VStack(spacing: 0) {
                        if isMacLayout {
                            macSheetHeader
                        }
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: sectionSpacing) {
                                titleField
                                propertyList
                                Divider()
                                notesSection
                                if !isCreating {
                                    Spacer(minLength: 24)
                                    bottomActionRow
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, topPadding)
                            .padding(.bottom, bottomPadding)
                            .frame(minHeight: proxy.size.height - (isMacLayout ? 64 : 0), alignment: .topLeading)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                }
            }
            .navigationTitle(isMacLayout ? "" : sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isMacLayout {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isCreating ? "Add" : "Save") { save() }
                            .disabled(!canSave)
                    }
                }
            }
            .onAppear { load() }
            .onChange(of: workingStart) { _, _ in disableReminderIfNoDates() }
            .onChange(of: dueDate) { _, _ in disableReminderIfNoDates() }
            .onChange(of: hasReminder) { _, isOn in
                if isOn { Task { await requestNotificationPermissionIfNeeded() } }
            }
            .onChange(of: showsCheckbox) { _, isOn in
                if !isOn { isChecked = false }
            }
            .alert("Save Failed", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .sheet(isPresented: $showStatusPicker) {
                StatusPickerSheet(board: board, selection: $selectedGroup)
                    .environmentObject(settings)
            }
            .sheet(isPresented: $showTagPicker) {
                TagPickerSheet(board: board, selection: $selectedTags)
                    .environmentObject(settings)
            }
            .sheet(isPresented: $showWorkingPicker) {
                workingDateSheet
                    .taskMacSheetFrame(width: 560, minHeight: 500)
                    .taskSheetPresentation(detents: [.fraction(0.7), .large], macHeight: 560)
            }
            .sheet(isPresented: $showDuePicker) {
                dueDateSheet
                    .taskMacSheetFrame(width: 540, minHeight: 460)
                    .taskSheetPresentation(macHeight: 520)
            }
            .sheet(isPresented: $showRepeatPicker) {
                RepeatPickerSheet(board: board, selection: $repeatRule)
                    .environmentObject(settings)
                    .taskMacSheetFrame(width: 540, minHeight: 430)
                    .taskSheetPresentation(macHeight: 500)
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
                .environmentObject(settings)
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
                .environmentObject(settings)
                .confirmationSheetPresentationStyle()
            }
        }
        .frame(minWidth: isMacLayout ? 680 : nil, minHeight: isMacLayout ? 620 : nil)
        .presentationDetents(taskDetailDetents)
        .presentationDragIndicator(isMacLayout ? .hidden : .visible)
        .dynamicTypeSize(settings.textSize.dynamicType)
    }

    // MARK: - Sections

    private var macSheetHeader: some View {
        ZStack {
            Text(sheetTitle)
                .font(.headline)
                .lineLimit(1)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.borderless)

                Spacer(minLength: 0)

                Button(isCreating ? "Add" : "Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var titleField: some View {
        TextField("", text: $title, prompt: Text("Add title").foregroundStyle(.secondary), axis: .vertical)
            .font(.system(size: titleFontSize, weight: .bold))
            .lineLimit(1...3)
            .textInputAutocapitalization(.words)
    }

    private var propertyList: some View {
        VStack(spacing: propertyRowSpacing) {
            statusRow
            tagsRow
            workingDateRow
            dueDateRow
            repeatRow
            checkboxRow
            reminderRow
        }
    }

    private var taskDetailDetents: Set<PresentationDetent> {
        isMacLayout ? [.large] : [.fraction(0.6), .large]
    }

    private var detailBackground: Color {
        isMacLayout ? Color(uiColor: .systemGroupedBackground) : Color(uiColor: .systemBackground)
    }

    private var sectionSpacing: CGFloat {
        isMacLayout ? 18 : 22
    }

    private var propertyRowSpacing: CGFloat {
        isMacLayout ? 10 : 14
    }

    private var horizontalPadding: CGFloat {
        isMacLayout ? 32 : 20
    }

    private var topPadding: CGFloat {
        isMacLayout ? 8 : 8
    }

    private var bottomPadding: CGFloat {
        isMacLayout ? 28 : 24
    }

    private var titleFontSize: CGFloat {
        isMacLayout ? min(settings.textSize.taskDetailTitleSize, 30) : settings.textSize.taskDetailTitleSize
    }

    private var labelColumnWidth: CGFloat {
        isMacLayout ? 104 : 120
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.system(.subheadline).weight(.semibold))
                .foregroundStyle(.secondary)
            MarkdownNotesEditor(text: $notes, bodyFontSize: settings.textSize.taskDetailNotesSize)
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
            SheetActionButtonLabel(title: "Delete Task", systemName: "trash", tintColor: .red)
        }
        .buttonStyle(.plain)
    }

    private var duplicateButton: some View {
        Button { showDuplicateConfirm = true } label: {
            SheetActionButtonLabel(title: "Duplicate Task", systemName: "doc.on.doc", tintColor: .accentColor)
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
                            .font(.system(size: settings.textSize.taskDetailPropertySize, weight: .semibold))
                            .foregroundStyle(tint)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        if reminderAnchor == .working {
                            Image(systemName: "alarm")
                                .font(.system(size: settings.textSize.taskDetailAccessoryIconSize, weight: .semibold))
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
                            .font(.system(size: settings.textSize.taskDetailPropertySize, weight: .semibold))
                            .foregroundStyle(tint)
                        Spacer(minLength: 8)
                        if reminderAnchor == .due {
                            Image(systemName: "alarm")
                                .font(.system(size: settings.textSize.taskDetailAccessoryIconSize, weight: .semibold))
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
                reminderWarning("Notifications are off for Task. Enable them in iOS Settings or this reminder won't fire.")
            }
            if hasReminder, reminderFireDateInPast {
                reminderWarning("Reminder date/time has already passed — this reminder won't fire. Pick a future date or change Reminder Time in Settings.")
            }
        }
    }

    private var checkboxRow: some View {
        propertyRow(icon: "checkmark.square", label: "Checkbox", valueAlignment: .trailing) {
            Toggle("", isOn: $showsCheckbox)
                .labelsHidden()
        }
    }

    private func reminderWarning(_ message: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 32)
    }

    /// `true` when the reminder's resolved fire time (anchor + board reminder
    /// hour/minute) is already in the past. Drives an inline warning so the silent
    /// `hasReminder` clear in `save()` isn't a surprise.
    private var reminderFireDateInPast: Bool {
        guard hasReminder else { return false }
        guard let fire = candidateFireDate() else { return false }
        return fire <= Date()
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
                            .font(.system(size: settings.textSize.taskDetailAccessoryIconSize, weight: .bold))
                            .foregroundStyle(ColorKey.gray.foreground)
                            .frame(width: 62, height: 30)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ColorKey.gray.background)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Advance to next occurrence"))
                }
            }
        }
    }

    // MARK: - Row helpers

    @ViewBuilder
    private func propertyRow<Content: View>(
        icon: String,
        label: LocalizedStringKey,
        valueAlignment: Alignment = .leading,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: settings.textSize.taskDetailRowIconSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: settings.textSize.taskDetailPropertySize, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: labelColumnWidth, alignment: .leading)
            value()
                .frame(maxWidth: .infinity, alignment: valueAlignment)
        }
        .frame(minHeight: isMacLayout ? 38 : 42)
        .contentShape(Rectangle())
    }

    private var emptyValueLabel: some View {
        Text("Empty")
            .font(.system(size: settings.textSize.taskDetailPropertySize, weight: .regular))
            .foregroundStyle(Color.secondary.opacity(0.6))
    }

    private func taskDetailChip(name: String, colorKey: ColorKey) -> some View {
        Text(name)
            .font(.system(size: settings.textSize.taskDetailChipSize, weight: .semibold))
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
                Color(isMacLayout ? .systemGroupedBackground : .systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: isMacLayout ? 18 : 22) {
                        rangeToggleRow
                        Divider()
                        workingCalendar
                    }
                    .padding(.horizontal, isMacLayout ? 24 : 20)
                    .padding(.top, isMacLayout ? 16 : 8)
                    .padding(.bottom, isMacLayout ? 28 : 24)
                }
            }
            .navigationTitle("Working Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showWorkingPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
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
                Color(isMacLayout ? .systemGroupedBackground : .systemBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: isMacLayout ? 18 : 22) {
                        CalendarPicker(selectedDate: $dueDate)
                    }
                    .padding(.horizontal, isMacLayout ? 24 : 20)
                    .padding(.top, isMacLayout ? 16 : 8)
                    .padding(.bottom, isMacLayout ? 28 : 24)
                }
            }
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDuePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
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
            showsCheckbox = task.showsCheckbox
            isChecked = task.isChecked
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
        task.showsCheckbox = showsCheckbox
        task.isChecked = showsCheckbox && isChecked
        let intendsReminder = hasReminder && (workingStart != nil || dueDate != nil)
        // A fire date in the past would never deliver a notification. Clear the flag
        // so the card/editor don't show the alarm icon for a reminder that won't fire.
        if intendsReminder, let fire = candidateFireDate(), fire <= Date() {
            task.hasReminder = false
        } else {
            task.hasReminder = intendsReminder
        }
        let canceledReminder = task.clearReminderIfCheckedCheckbox()
        task.repeatRule = repeatRule
        task.touch()

        do {
            try context.save()
        } catch {
            // Save failed — don't schedule/cancel notifications or update the widget
            // for state that didn't commit. Roll back the model object mutations so
            // a later unrelated save doesn't persist a rejected edit.
            context.rollback()
            saveErrorMessage = String(localized: "Couldn't save this task. Try again.")
            return
        }

        if canceledReminder {
            NotificationService.cancel(for: task)
        } else if task.hasReminder {
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

private extension AppTextSize {
    var taskDetailTitleSize: CGFloat {
        switch self {
        case .small:      return 22
        case .medium:     return 24
        case .large:      return 26
        case .extraLarge: return 28
        }
    }

    var taskDetailPropertySize: CGFloat {
        switch self {
        case .small:      return 15
        case .medium:     return 16
        case .large:      return 17
        case .extraLarge: return 18
        }
    }

    var taskDetailNotesSize: CGFloat {
        switch self {
        case .small:      return 17
        case .medium:     return 19
        case .large:      return 21
        case .extraLarge: return 23
        }
    }

    var taskDetailChipSize: CGFloat {
        switch self {
        case .small:      return 15
        case .medium:     return 16
        case .large:      return 17
        case .extraLarge: return 18
        }
    }

    var taskDetailRowIconSize: CGFloat {
        switch self {
        case .small:      return 15
        case .medium:     return 16
        case .large:      return 17
        case .extraLarge: return 18
        }
    }

    var taskDetailAccessoryIconSize: CGFloat {
        switch self {
        case .small:      return 14
        case .medium:     return 15
        case .large:      return 16
        case .extraLarge: return 17
        }
    }
}
