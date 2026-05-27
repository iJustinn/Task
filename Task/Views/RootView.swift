import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

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
            if PlatformLayout.prefersMacInterface {
                macContent(board: board)
            } else {
                mobileContent(board: board)
            }
        }
        .sheet(isPresented: $showingAddTask) {
            TaskDetailView(board: board, mode: .create(defaultGroup: board.defaultGroup))
                .environmentObject(settings)
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet(board: board)
        }
        .sheet(isPresented: $showingBoardSwitcher) {
            BoardSwitcherView(activeBoardID: board.id) { picked in
                activeBoardIDString = picked.uuidString
            }
            .environmentObject(settings)
        }
        .sheet(item: $editingTaskFromSearch) { task in
            TaskDetailView(board: task.board ?? board, mode: .edit(task))
                .environmentObject(settings)
        }
        .task {
            // Permission is requested only when the user opts in to a reminder
            // (see TaskDetailView.requestNotificationPermissionIfNeeded). The launch
            // path just reads the current status so banners are accurate.
            await settings.refreshNotificationAuthorization()
            UpcomingSnapshotBuilder.writeSnapshot(from: context)
        }
    }

    @ViewBuilder
    private func settingsSheet(board: Board) -> some View {
        if PlatformLayout.prefersMacInterface {
            SettingsView(board: board)
                .environmentObject(settings)
                .taskSheetPresentation(macHeight: 680)
        } else {
            SettingsView(board: board)
                .environmentObject(settings)
        }
    }

    private func mobileContent(board: Board) -> some View {
        ZStack {
            BoardView(board: board, layoutStyle: .mobile)
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
            .navigationSplitViewColumnWidth(min: 220, ideal: 248, max: 280)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingBoardSwitcher = true
                    } label: {
                        Label("Manage Boards", systemImage: "rectangle.stack")
                    }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                }
            }
        } detail: {
            macDetail(board: board)
        }
        .frame(minWidth: 980, minHeight: 680)
        .background(macWindowTitleSuppressor)
    }

    @ViewBuilder
    private var macWindowTitleSuppressor: some View {
        #if canImport(UIKit)
        MacWindowTitleSuppressor()
            .frame(width: 0, height: 0)
        #else
        EmptyView()
        #endif
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
        BoardView(board: board, layoutStyle: .mac, searchQuery: searchText)
            .id(board.id)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Label("New Task", systemImage: "plus")
                            .frame(width: 36, height: 36)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .buttonBorderShape(.circle)
                    .help("New Task")
                    .keyboardShortcut("n", modifiers: .command)

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .frame(width: 36, height: 36)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .buttonBorderShape(.circle)
                    .help("Settings")
                    .keyboardShortcut(",", modifiers: .command)
                }
            }
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
            .animation(.easeInOut(duration: 0.18), value: searchText)
            .animation(.easeInOut(duration: 0.32), value: board.id)
    }

    private var isSearchActive: Bool {
        searchFocused || !searchText.isEmpty
    }
}

enum MacSidebarBoardLabel {
    static func taskCountText(for count: Int) -> String {
        count == 1 ? "1 task" : "\(count) tasks"
    }
}

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

#if canImport(UIKit)
private struct MacWindowTitleSuppressor: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        clearTitle(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        clearTitle(from: uiView)
    }

    private func clearTitle(from view: UIView) {
        guard PlatformLayout.prefersMacInterface else { return }
        DispatchQueue.main.async {
            guard let windowScene = view.window?.windowScene else { return }
            windowScene.title = ""
            #if targetEnvironment(macCatalyst)
            windowScene.titlebar?.titleVisibility = .hidden
            #endif
        }
    }
}
#endif
