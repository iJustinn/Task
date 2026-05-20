import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: SettingsViewModel
    @Query private var boards: [Board]

    @State private var searchText: String = ""
    @State private var searchFocused: Bool = false
    @State private var showingAddTask: Bool = false
    @State private var showingSettings: Bool = false
    @State private var editingTaskFromSearch: TaskItem?
    @State private var showingInMemoryWarning: Bool = false

    var body: some View {
        Group {
            if let board = boards.first {
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

    private func surfaceInMemoryWarningIfNeeded() {
        if UserDefaults.standard.bool(forKey: SwiftDataManager.inMemoryFallbackKey) {
            showingInMemoryWarning = true
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
        .overlay(alignment: .bottom) {
            BottomNavBar(
                searchText: $searchText,
                onAdd: { showingAddTask = true },
                onSettings: { showingSettings = true },
                onFocusChange: { focused in searchFocused = focused }
            )
        }
        .sheet(isPresented: $showingAddTask) {
            TaskDetailView(board: board, mode: .create(defaultGroup: settings.defaultGroup(in: board)))
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
