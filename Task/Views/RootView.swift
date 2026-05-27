import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settings: SettingsViewModel
    @Query(sort: \Board.sortIndex) private var boards: [Board]

    @AppStorage("task.activeBoardID") private var activeBoardIDString: String = ""

    @State private var searchText: String = ""
    @State private var searchFocused: Bool = false
    @State private var showingAddTask: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingBoardSwitcher: Bool = false
    @State private var editingTaskFromSearch: TaskItem?
    @State private var showingInMemoryWarning: Bool = false
    @State private var macColumnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if let board = activeBoard {
                content(board: board)
            } else {
                ProgressView()
                    .onAppear { SwiftDataManager.ensureSeed(context: context) }
            }
        }
        .onAppear(perform: surfaceInMemoryWarningIfNeeded)
        .onChange(of: scenePhase) { _, phase in
            // The user may have changed notification permission in iOS Settings while
            // the app was backgrounded; re-read so TaskDetailView's warning is accurate.
            // Also reconcile repeating reminders so stale task dates advance and
            // legacy future batches are removed before scheduling the next ring.
            if phase == .active {
                Task { await settings.refreshNotificationAuthorization() }
                refreshRepeatReminders()
            }
        }
        .alert("Storage Error", isPresented: $showingInMemoryWarning) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Task couldn't open its on-device database, so your changes this session won't be saved. Please export your data from Settings → Data → Manual Control and restart the app.")
        }
    }

    private var activeBoard: Board? {
        if let uuid = UUID(uuidString: activeBoardIDString),
           let match = boards.first(where: { $0.id == uuid }) {
            return match
        }
        return boards.first
    }

    private func surfaceInMemoryWarningIfNeeded() {
        if UserDefaults.standard.bool(forKey: SwiftDataManager.inMemoryFallbackKey) {
            showingInMemoryWarning = true
        }
    }

    /// Re-schedule every repeating task's reminder request. If the task's reminder
    /// date has elapsed, advance its card dates by the repeat rule until the next
    /// reminder is in the future, then persist once before scheduling.
    private func refreshRepeatReminders() {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.hasReminder && !$0.repeatRuleRaw.isEmpty }
        )
        guard let tasks = try? context.fetch(descriptor) else { return }
        var didAdvance = false
        for task in tasks {
            didAdvance = NotificationService.advanceRepeatingReminderIfNeeded(for: task) || didAdvance
        }

        if didAdvance {
            do {
                try context.save()
                UpcomingSnapshotBuilder.writeSnapshot(from: context)
            } catch {
                context.rollback()
                return
            }
        }

        for task in tasks {
            NotificationService.schedule(for: task)
        }
    }

    @ViewBuilder
    private func content(board: Board) -> some View {
        Group {
            #if targetEnvironment(macCatalyst)
            macContent(board: board)
            #else
            mobileContent(board: board)
            #endif
        }
        .sheet(isPresented: $showingAddTask) {
            TaskDetailView(board: board, mode: .create(defaultGroup: board.defaultGroup))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(board: board)
        }
        .sheet(isPresented: $showingBoardSwitcher) {
            BoardSwitcherView(activeBoardID: board.id) { picked in
                activeBoardIDString = picked.uuidString
            }
        }
        .sheet(item: $editingTaskFromSearch) { task in
            TaskDetailView(board: task.board ?? board, mode: .edit(task))
        }
        .task {
            // Permission is requested only when the user opts in to a reminder
            // (see TaskDetailView.requestNotificationPermissionIfNeeded). The launch
            // path just reads the current status so banners are accurate.
            await settings.refreshNotificationAuthorization()
            UpcomingSnapshotBuilder.writeSnapshot(from: context)
        }
    }

    private func mobileContent(board: Board) -> some View {
        ZStack {
            BoardView(board: board)
                .id(board.id)
                .opacity(isSearchActive ? 0 : 1)
                .allowsHitTesting(!isSearchActive)
                .transition(.opacity)

            if isSearchActive {
                SearchView(boards: boards, activeBoardID: board.id, queryText: searchText) { task in
                    editingTaskFromSearch = task
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSearchActive)
        .animation(.easeInOut(duration: 0.32), value: board.id)
        .overlay(alignment: .bottom) {
            BottomNavBar(
                searchText: $searchText,
                onAdd: { showingAddTask = true },
                onSwitchBoard: { showingBoardSwitcher = true },
                onSettings: { showingSettings = true },
                onFocusChange: { focused in searchFocused = focused }
            )
        }
    }

    #if targetEnvironment(macCatalyst)
    private func macContent(board: Board) -> some View {
        NavigationSplitView(columnVisibility: $macColumnVisibility) {
            List(selection: macSidebarSelection) {
                Section("Boards") {
                    ForEach(boards, id: \.id) { board in
                        MacSidebarBoardRow(board: board)
                            .tag(Optional(board.id))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Task")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingBoardSwitcher = true
                    } label: {
                        Label("Manage Boards", systemImage: "rectangle.stack")
                    }
                }
            }
        } detail: {
            macDetail(board: board)
        }
    }

    private var macSidebarSelection: Binding<UUID?> {
        Binding(
            get: { activeBoard?.id },
            set: { picked in
                guard let picked else { return }
                activeBoardIDString = picked.uuidString
                searchText = ""
                editingTaskFromSearch = nil
            }
        )
    }

    private func macDetail(board: Board) -> some View {
        ZStack {
            BoardView(board: board)
                .id(board.id)
                .opacity(hasSearchQuery ? 0 : 1)
                .allowsHitTesting(!hasSearchQuery)
                .transition(.opacity)

            if hasSearchQuery {
                SearchView(boards: boards, activeBoardID: board.id, queryText: searchText) { task in
                    editingTaskFromSearch = task
                }
                .transition(.opacity)
            }
        }
        .navigationTitle(board.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingAddTask = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }

                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        .animation(.easeInOut(duration: 0.18), value: hasSearchQuery)
        .animation(.easeInOut(duration: 0.32), value: board.id)
    }
    #endif

    private var isSearchActive: Bool {
        searchFocused || !searchText.isEmpty
    }

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum MacSidebarBoardLabel {
    static func taskCountText(for count: Int) -> String {
        count == 1 ? "1 task" : "\(count) tasks"
    }
}

#if targetEnvironment(macCatalyst)
private struct MacSidebarBoardRow: View {
    let board: Board

    var body: some View {
        HStack(spacing: 10) {
            Text(board.iconEmoji)
                .font(.title3)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(board.title.isEmpty ? String(localized: "Untitled") : board.title)
                    .lineLimit(1)

                Text(MacSidebarBoardLabel.taskCountText(for: board.tasks?.count ?? 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
