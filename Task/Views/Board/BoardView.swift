import SwiftUI
import SwiftData

struct BoardView: View {
    let board: Board
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var editingGroup: BoardGroup?
    @State private var editingTask: TaskItem?
    @State private var showingDateFilter: Bool = false
    @State private var dateFilterOpenToken: Int = 0
    @State private var selectedDateFilter: Date?
    @State private var draggingTaskID: UUID?
    @State private var dragSessionEnded: Bool = false
    @State private var refreshToken: Int = 0
    /// Pre-drag (groupID, sortIndex) per task captured the first time `placeTask`
    /// runs with `commit: false`. If the user releases outside any drop target,
    /// `dragWatchdog` fires and restores these values so the unsaved mutations
    /// don't silently commit on the next unrelated save.
    @State private var preDragState: [UUID: (groupID: UUID?, sortIndex: Int)] = [:]
    @State private var dragWatchdog: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderView(
                board: board,
                isDateFilterActive: selectedDateFilter != nil,
                onDateFilterTap: toggleDateFilter
            )
            Divider().opacity(0.4)
            if showingDateFilter {
                dateFilterSlider
                    .transition(.move(edge: .top).combined(with: .opacity))
                Divider().opacity(0.4)
            }
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(board.orderedGroups, id: \.id) { group in
                            ColumnView(
                                group: group,
                                width: settings.columnWidth.width,
                                sortField: board.cardSortField,
                                sortDirection: board.cardSortDirection,
                                dateFilter: selectedDateFilter,
                                dateFilterTarget: settings.dateFilterTarget,
                                isDefaultStatus: board.defaultGroup?.id == group.id,
                                draggingTaskID: $draggingTaskID,
                                dragSessionEnded: $dragSessionEnded,
                                refreshToken: refreshToken,
                                onTapTask: { task in editingTask = task },
                                onMenuTap: { editingGroup = group },
                                onPlaceTask: { task, index, commit in placeTask(task, in: group, atIndex: index, commit: commit) },
                                onGroupReorder: { dragged in reorderGroup(dragged, toPositionOf: group) },
                                onDragTick: { rearmDragWatchdogIfDragging() }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 112)
                    .frame(minHeight: geo.size.height, alignment: .topLeading)
                }
                .refreshable {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    refreshToken &+= 1
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .sheet(item: $editingGroup) { group in
            GroupMenuSheet(group: group, board: board)
        }
        .sheet(item: $editingTask) { task in
            TaskDetailView(board: board, mode: .edit(task))
        }
        .onChange(of: board.id) { _, _ in
            selectedDateFilter = nil
            showingDateFilter = false
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: showingDateFilter)
    }

    private var dateFilterSlider: some View {
        BoardDateSlider(
            selectedDate: $selectedDateFilter,
            openToken: dateFilterOpenToken,
            dates: BoardDateSliderDayWindow.dates(
                for: board.tasks ?? [],
                target: settings.dateFilterTarget,
                fallback: selectedDateFilter ?? Date()
            )
        )
            .background(Color(.systemBackground))
    }

    private func toggleDateFilter() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            showingDateFilter.toggle()
            if showingDateFilter {
                dateFilterOpenToken &+= 1
            }
        }
    }

    /// Reassigns the task's group if needed, places it at `index` in the destination
    /// column's manual order, renumbers sortIndex, and (when `commit` is true) saves
    /// + refreshes the widget snapshot. `commit: false` is used during the live drag
    /// to animate without persisting until the user releases. Skips work entirely
    /// when the move would be a no-op so live drag doesn't bounce.
    private func placeTask(_ task: TaskItem, in group: BoardGroup, atIndex index: Int, commit: Bool) {
        if !commit {
            // First hover of a fresh drag — capture every task's anchor so we can
            // roll back if the drag is released outside any drop target.
            captureSnapshotIfNeeded()
            armDragWatchdog()
        } else {
            dragWatchdog?.cancel()
            dragWatchdog = nil
            preDragState.removeAll()
        }

        let crossColumn = task.group?.id != group.id
        let currentOrdered = group.orderedTasks
        let withoutTask = currentOrdered.filter { $0.id != task.id }
        let safeIndex = max(0, min(index, withoutTask.count))
        if !crossColumn,
           let currentIndex = currentOrdered.firstIndex(where: { $0.id == task.id }),
           currentIndex == safeIndex {
            if commit { try? context.save() }
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            if crossColumn {
                task.group = group
                task.touch()
            }
            var newOrdered = withoutTask
            newOrdered.insert(task, at: safeIndex)
            for (i, t) in newOrdered.enumerated() {
                if t.sortIndex != i {
                    t.sortIndex = i
                }
            }
        }
        if commit {
            try? context.save()
            UpcomingSnapshotBuilder.writeSnapshot(from: context)
        }
    }

    private func captureSnapshotIfNeeded() {
        guard preDragState.isEmpty, let tasks = board.tasks else { return }
        var snap: [UUID: (groupID: UUID?, sortIndex: Int)] = [:]
        snap.reserveCapacity(tasks.count)
        for t in tasks {
            snap[t.id] = (t.group?.id, t.sortIndex)
        }
        preDragState = snap
    }

    /// Cancel + re-arm a 5-second watchdog. `dropEntered` only fires once per
    /// target entry, so the row delegate also re-arms from `dropUpdated` via
    /// `onDragTick` — that's what keeps the timer fresh during a slow hover and
    /// stops the watchdog from rolling back mid-drag. Only a stationary stretch
    /// with no drag events (or a release outside any drop target) lets it elapse.
    private func armDragWatchdog() {
        dragWatchdog?.cancel()
        dragWatchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if Task.isCancelled { return }
            rollbackDragIfNeeded()
        }
    }

    /// Re-arm the watchdog only when a drag is actually in flight (preDragState
    /// captured). Cheap to call from `dropUpdated`'s continuous tick.
    private func rearmDragWatchdogIfDragging() {
        guard !preDragState.isEmpty else { return }
        armDragWatchdog()
    }

    private func rollbackDragIfNeeded() {
        guard !preDragState.isEmpty else { return }
        let groupsByID: [UUID: BoardGroup] = Dictionary(
            uniqueKeysWithValues: board.orderedGroups.map { ($0.id, $0) }
        )
        let tasks = board.tasks ?? []
        withAnimation(.easeInOut(duration: 0.18)) {
            for t in tasks {
                guard let original = preDragState[t.id] else { continue }
                if t.sortIndex != original.sortIndex {
                    t.sortIndex = original.sortIndex
                }
                let originalGroup = original.groupID.flatMap { groupsByID[$0] }
                if t.group?.id != original.groupID {
                    t.group = originalGroup
                }
            }
        }
        try? context.save()
        preDragState.removeAll()
        dragWatchdog = nil
    }

    private func reorderGroup(_ dragged: BoardGroup, toPositionOf target: BoardGroup) {
        guard dragged.id != target.id else { return }
        var ordered = board.orderedGroups
        guard let from = ordered.firstIndex(where: { $0.id == dragged.id }),
              let to = ordered.firstIndex(where: { $0.id == target.id }) else { return }
        let item = ordered.remove(at: from)
        ordered.insert(item, at: to)
        for (i, g) in ordered.enumerated() {
            g.sortIndex = i
        }
        try? context.save()
    }
}

struct BoardDateSliderDayWindow {
    static func dates(
        for tasks: [TaskItem],
        target: AppDateFilterTarget,
        fallback: Date = Date(),
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date] {
        let focusDay = calendar.startOfDay(for: fallback)
        let todayDay = calendar.startOfDay(for: today)
        let lowerCap = calendar.date(byAdding: .year, value: -1, to: todayDay) ?? todayDay
        let upperCap = calendar.date(byAdding: .year, value: 1, to: todayDay) ?? todayDay

        let candidateBounds: [Date]
        switch target {
        case .workingDate:
            candidateBounds = tasks.flatMap { task -> [Date] in
                guard let start = task.workingStart else { return [] }
                return [start, task.workingEnd ?? start].map { calendar.startOfDay(for: $0) }
            }
        case .dueDate:
            candidateBounds = tasks.compactMap(\.dueDate).map { calendar.startOfDay(for: $0) }
        }

        var bounds = candidateBounds.filter { $0 >= lowerCap && $0 <= upperCap }
        if focusDay >= lowerCap && focusDay <= upperCap {
            bounds.append(focusDay)
        }
        guard let first = bounds.min(), let last = bounds.max() else {
            return [todayDay]
        }

        var days: [Date] = []
        var day = first
        while day <= last {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }
}

private struct BoardDateSlider: View {
    @Binding var selectedDate: Date?
    let openToken: Int
    let dates: [Date]
    @Environment(\.colorScheme) private var colorScheme
    @State private var scrollPosition: Date?

    @ScaledMetric(relativeTo: .title2) private var tileWidth: CGFloat = 62
    @ScaledMetric(relativeTo: .title2) private var tileHeight: CGFloat = 78
    @ScaledMetric(relativeTo: .title2) private var tileCornerRadius: CGFloat = 14

    private let calendar: Calendar = .current

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    var body: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(dates, id: \.self) { date in
                        dateTile(for: date)
                            .id(date)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            edgeShade
                .allowsHitTesting(false)
        }
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .onAppear {
            recenter()
        }
        .onChange(of: dates) { _, _ in
            recenter()
        }
        .onChange(of: openToken) { _, _ in
            recenter()
        }
        .frame(height: tileHeight + 24)
    }

    private func recenter() {
        let target = scrollTarget
        scrollPosition = nil
        DispatchQueue.main.async {
            scrollPosition = target
        }
    }

    private var scrollTarget: Date {
        let target = selectedDate.map { calendar.startOfDay(for: $0) } ?? today
        if dates.contains(where: { calendar.isDate($0, inSameDayAs: target) }) {
            return target
        }
        if dates.contains(where: { calendar.isDate($0, inSameDayAs: today) }) {
            return today
        }
        return dates.min(by: {
            abs($0.timeIntervalSince(today)) < abs($1.timeIntervalSince(today))
        }) ?? today
    }

    private func dateTile(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false

        return Button {
            if isSelected {
                selectedDate = nil
            } else {
                selectedDate = day
            }
        } label: {
            VStack(spacing: 5) {
                Text(day.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(day.formatted(.dateTime.day()))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(foregroundColor(isSelected: isSelected))
            .frame(width: tileWidth, height: tileHeight)
            .background(
                RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                    .fill(tileFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : tileStrokeColor,
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: tileCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
        .accessibilityHint(isSelected ? Text("Show all tasks") : Text("Filter tasks by this date"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tileFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.055)
            : Color.primary.opacity(0.035)
    }

    private func foregroundColor(isSelected: Bool) -> Color {
        isSelected ? .primary : .primary.opacity(0.82)
    }

    private var tileStrokeColor: Color {
        return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.11)
    }

    private var edgeShade: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemBackground).opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 22)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 22)
        }
    }
}
