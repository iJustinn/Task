import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
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
            await NotificationService.requestAuthorizationIfNeeded()
            UpcomingSnapshotBuilder.writeSnapshot(from: context)
        }
    }

    private var isSearchActive: Bool {
        searchFocused || !searchText.isEmpty
    }
}
