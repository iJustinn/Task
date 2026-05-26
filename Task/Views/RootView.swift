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
            // Also reconcile repeating reminders so legacy future batches are
            // removed and only the task card's current date remains scheduled.
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

    /// Re-schedule every repeating task's reminder request. This keeps old
    /// repeat-batch identifiers cleaned up after upgrades without creating new
    /// future occurrences unless the task card's own date was moved forward.
    private func refreshRepeatReminders() {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.hasReminder && !$0.repeatRuleRaw.isEmpty }
        )
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks {
            NotificationService.schedule(for: task)
        }
    }

    @ViewBuilder
    private func content(board: Board) -> some View {
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

    private var isSearchActive: Bool {
        searchFocused || !searchText.isEmpty
    }
}
