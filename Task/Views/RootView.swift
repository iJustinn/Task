import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var boards: [Board]

    @State private var searchText: String = ""
    @State private var searchFocused: Bool = false
    @State private var showingAddTask: Bool = false
    @State private var showingSettings: Bool = false
    @State private var editingTaskFromSearch: TaskItem?

    var body: some View {
        Group {
            if let board = boards.first {
                content(board: board)
            } else {
                ProgressView()
                    .onAppear { SwiftDataManager.ensureSeed(context: context) }
            }
        }
    }

    @ViewBuilder
    private func content(board: Board) -> some View {
        ZStack {
            BoardView(board: board)
                .opacity(isSearchActive ? 0 : 1)
                .allowsHitTesting(!isSearchActive)

            if isSearchActive {
                SearchView(board: board, queryText: searchText) { task in
                    editingTaskFromSearch = task
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSearchActive)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavBar(
                searchText: $searchText,
                onAdd: { showingAddTask = true },
                onSettings: { showingSettings = true },
                onFocusChange: { focused in searchFocused = focused }
            )
        }
        .sheet(isPresented: $showingAddTask) {
            TaskDetailView(board: board, mode: .create(defaultGroup: board.orderedGroups.first))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(board: board)
        }
        .sheet(item: $editingTaskFromSearch) { task in
            TaskDetailView(board: board, mode: .edit(task))
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
