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

    private var editingTask: TaskItem? {
        if case .edit(let task) = mode { return task }
        return nil
    }

    private var isCreating: Bool { editingTask == nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        titleCard
                        propertiesCard
                        notesCard
                        if !isCreating { deleteCard }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isCreating ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isCreating ? "Add" : "Save") { save() }
                        .fontWeight(.bold)
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
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showDuePicker) {
                dueDateSheet
                    .presentationDetents([.medium, .large])
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
    }

    // MARK: - Cards

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $title, prompt: Text("Add title").foregroundStyle(.secondary), axis: .vertical)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .lineLimit(1...3)
                .textInputAutocapitalization(.words)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .taskCardBackground()
    }

    private var propertiesCard: some View {
        VStack(spacing: 0) {
            statusRow
            SettingsRowDivider()
            tagsRow
            SettingsRowDivider()
            workingDateRow
            SettingsRowDivider()
            dueDateRow
            SettingsRowDivider()
            reminderRow
        }
        .taskCardBackground()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                SettingsIconTile(systemName: "doc.text", color: .gray)
                Text("Notes")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
            }
            TextField("Add notes", text: $notes, axis: .vertical)
                .lineLimit(4...20)
                .padding(.leading, 58)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .taskCardBackground()
    }

    private var deleteCard: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: "trash")
                    .font(.system(.subheadline, weight: .bold))
                Text("Delete Task")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundColor(.red)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .taskCardBackground()
    }

    // MARK: - Rows

    private var statusRow: some View {
        Button { showStatusPicker = true } label: {
            HStack(spacing: 14) {
                SettingsIconTile(systemName: "circle.dotted", color: selectedGroup?.colorKey.foreground ?? .secondary)
                Text("Status")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                if let group = selectedGroup {
                    HStack(spacing: 5) {
                        Circle().fill(group.colorKey.dot).frame(width: 8, height: 8)
                        Text(group.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(group.colorKey.foreground)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(group.colorKey.background))
                } else {
                    Text("Empty").font(.system(.headline, design: .rounded)).foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right").font(.system(.caption, weight: .bold)).foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tagsRow: some View {
        Button { showTagPicker = true } label: {
            HStack(spacing: 14) {
                SettingsIconTile(systemName: "tag.fill", color: .orange)
                Text("Tags")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                if selectedTags.isEmpty {
                    Text("Empty").font(.system(.headline, design: .rounded)).foregroundColor(.secondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(selectedTags.prefix(3), id: \.id) { tag in
                            TagChip(name: tag.name, colorKey: tag.colorKey)
                        }
                        if selectedTags.count > 3 {
                            Text("+\(selectedTags.count - 3)").font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }
                Image(systemName: "chevron.right").font(.system(.caption, weight: .bold)).foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var workingDateRow: some View {
        Button { showWorkingPicker = true } label: {
            HStack(spacing: 14) {
                SettingsIconTile(systemName: "calendar", color: .blue)
                Text("Working date")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                if let start = workingStart {
                    Text(TaskDateFormat.formatRange(start, isWorkingRange ? workingEnd : nil))
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("Empty").font(.system(.headline, design: .rounded)).foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right").font(.system(.caption, weight: .bold)).foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dueDateRow: some View {
        Button { showDuePicker = true } label: {
            HStack(spacing: 14) {
                SettingsIconTile(systemName: "calendar.badge.exclamationmark", color: .red)
                Text("Due date")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                Spacer()
                if let due = dueDate {
                    Text(TaskDateFormat.format(due))
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text("Empty").font(.system(.headline, design: .rounded)).foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right").font(.system(.caption, weight: .bold)).foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var reminderRow: some View {
        HStack(spacing: 14) {
            SettingsIconTile(systemName: "alarm", color: hasReminder ? .pink : .gray)
            Text("Reminder")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
            Spacer()
            Toggle("", isOn: $hasReminder).labelsHidden()
                .disabled(workingStart == nil && dueDate == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }

    // MARK: - Date sheets

    private var workingDateSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        rangeToggleCard
                        workingCalendarCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Working Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showWorkingPicker = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showWorkingPicker = false }.fontWeight(.bold)
                }
            }
        }
    }

    @ViewBuilder
    private var workingCalendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isWorkingRange {
                CalendarPicker(rangeStart: $workingStart, rangeEnd: $workingEnd)
            } else {
                CalendarPicker(selectedDate: $workingStart)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .taskCardBackground()
    }

    private var dueDateSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        calendarCard(title: "", selection: $dueDate)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 60)
                }
            }
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showDuePicker = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showDuePicker = false }.fontWeight(.bold)
                }
            }
        }
    }

    private func calendarCard(title: String, selection: Binding<Date?>, minimumDate: Date? = nil, maximumDate: Date? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            CalendarPicker(selectedDate: selection, minimumDate: minimumDate, maximumDate: maximumDate)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .taskCardBackground()
    }

    private var rangeToggleCard: some View {
        Toggle(isOn: $isWorkingRange) {
            HStack(spacing: 14) {
                SettingsIconTile(systemName: "calendar.day.timeline.right", color: .purple)
                Text("End Date")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: isWorkingRange) { _, on in
            if !on { workingEnd = nil }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .taskCardBackground()
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
