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

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var selectedGroup: BoardGroup?
    @State private var selectedTags: [TaskTag] = []
    @State private var workingStart: Date? = nil
    @State private var workingEnd: Date? = nil
    @State private var dueDate: Date? = nil
    @State private var hasReminder: Bool = false
    @State private var isWorkingRange: Bool = false
    @State private var didLoad: Bool = false

    @State private var showStatusPicker: Bool = false
    @State private var showTagPicker: Bool = false
    @State private var showWorkingPicker: Bool = false
    @State private var showDuePicker: Bool = false
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
            .sheet(isPresented: $showStatusPicker) {
                StatusPickerSheet(board: board, selection: $selectedGroup)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTagPicker) {
                TagPickerSheet(board: board, selection: $selectedTags)
                    .presentationDetents([.medium, .large])
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
        propertyRow(icon: "alarm", label: "Reminder", valueAlignment: .trailing) {
            Toggle("", isOn: $hasReminder)
                .labelsHidden()
                .disabled(workingStart == nil && dueDate == nil)
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
        task.hasReminder = hasReminder && (workingStart != nil || dueDate != nil)
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

    private func delete() {
        guard let task = editingTask else { return }
        NotificationService.cancel(for: task)
        context.delete(task)
        try? context.save()
        UpcomingSnapshotBuilder.writeSnapshot(from: context)
        dismiss()
    }
}
