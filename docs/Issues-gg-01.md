# Project Code Review & Issues Report — Task v0.4.5

This document details the issues, bugs, performance concerns, and structural improvements identified in the **Task** codebase (branch `task-v0.4.5`).

---

## Critical Bugs

### 1. Repeating Reminders Premature Fire
*   **Severity:** High / Critical
*   **Location:** [NotificationService.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/NotificationService.swift) in function [NotificationService.repeatComponents(rule:base:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/NotificationService.swift#L60-L71) called inside [NotificationService.schedule(for:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/NotificationService.swift#L16-L55)
*   **Explanation:**
    When scheduling recurring notifications, [repeatComponents(rule:base:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/NotificationService.swift#L60-L71) strips the `year`, `month`, and `day` properties to match daily/weekly/monthly cadences:
    *   Daily: retains only `hour` and `minute`.
    *   Weekly: retains only `hour`, `minute`, and `weekday`.
    *   Monthly: retains only `day`, `hour`, and `minute`.

    When these stripped components are fed into `UNCalendarNotificationTrigger(dateMatching:triggerComponents, repeats: true)`, iOS schedules the very first notification at the next clock matching the remaining components. If a task has a future reminder date (e.g., set to start in 3 weeks), the trigger will fire immediately at the next matching time (e.g., tomorrow morning), completely ignoring the future start/anchor date.
*   **Why it matters:**
    Repeating reminders are broken for any task scheduled to start in the future. The user will receive premature notifications, rendering the reminder feature misleading and buggy.
*   **Suggested fix:**
    Check if the initial `fireDate` is in the future (`fireDate > Date()`). If so:
    1.  Schedule a non-repeating one-off trigger for that specific future date (`repeats: false` using full date components).
    2.  Once that first event is marked done or when the user shifts dates manually, schedule the repeating trigger components.

---

### 2. SwiftData In-Memory Mutated State on Cancelled Drag & Drop
*   **Severity:** High
*   **Location:**
    *   [ColumnView.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Board/ColumnView.swift) in function [TaskRowDropDelegate.applyTaskMove(_:atIndex:commit:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Board/ColumnView.swift#L270-L281) called inside [dropEntered(info:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Board/ColumnView.swift#L219-L230)
    *   [BoardView.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Board/BoardView.swift) in function [BoardView.placeTask(_:in:atIndex:commit:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Board/BoardView.swift#L63-L91)
*   **Explanation:**
    During an active card drag gesture across columns, `onPlaceTask` is called with `commit: false` to animate columns shifting. This updates `task.group` and `t.sortIndex` in memory on the main `ModelContext`. If the user cancels the drag (e.g., by releasing the card outside a valid drop target, off-screen, or backgrounding the app), the drop delegate does not call `performDrop` or save the context, and the visual card returns to its original position.

    However, the in-memory properties of the task are **not** rolled back. The next time the user saves *any* change (such as editing another task or adding a new task), SwiftData commits the dirty in-memory state, permanently relocating the aborted task into the wrong group/column on disk.
*   **Why it matters:**
    Causes severe data inconsistency. An aborted user gesture results in silent, delayed changes to task columns.
*   **Suggested fix:**
    Do not mutate [TaskItem](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Models/TaskItem.swift#L5) model objects directly in memory during live dragging (`commit: false`). Instead, track visual position shifts using SwiftUI layout coordinates or custom `@State` bindings. Mutate and save the actual database model objects only upon a successful drop confirmation (`commit: true`).

---

## Data Processing Issues

### 3. Silenced Failures in JSON Data Import
*   **Severity:** Medium
*   **Location:** [DataImportExport.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/DataImportExport.swift) in function [DataImportExport.importData(_:context:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/DataImportExport.swift#L247-L277)
*   **Explanation:**
    At the end of the JSON import process, the app calls `try? context.save()`. If the save fails (due to validation errors, write permissions, or corrupt state), the failure is silently caught and ignored. The method proceeds to return an `ImportResult` with `success: true`.
*   **Why it matters:**
    Provides a false success message to the user, leading to silent data loss.
*   **Suggested fix:**
    Verify the return or catch errors thrown during `context.save()`. If the save fails, return `success: false` and display an error alert to the user.

---

### 4. Incomplete Cleanup of Corrupted Persistent Store on Hard Reset
*   **Severity:** High
*   **Location:** [DataImportExport.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/DataImportExport.swift) in function [DataImportExport.resetAll(context:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/DataImportExport.swift#L443-L458)
*   **Explanation:**
    If the app fails to load the SQLite container (due to schema mismatch or file corruption) and falls back to an in-memory store, the user is locked out of their saved data. While the user can click "Reset All Data" to rebuild the boards, [resetAll(context:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/DataImportExport.swift#L443-L458) only deletes the active [Board](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Models/Board.swift#L5) objects in the current context. Because the store is in-memory, the corrupted SQLite database files on disk are never touched. Relaunching the app will try to load the corrupted database file, fail again, and fall back to in-memory mode again.
*   **Why it matters:**
    The user is trapped in an in-memory loop and cannot repair their installation without deleting and reinstalling the app entirely.
*   **Suggested fix:**
    If the app has loaded in in-memory fallback mode or during a hard reset, locate and physically delete the SQLite file on disk using `FileManager` to allow the app to rebuild a clean container on the next launch.

---

## Model / Data Science Issues

*   **None / Not Applicable:** This is a client-side productivity application; no data science models or ML inference pipelines are present.

---

## UI / Dashboard Issues

### 5. Stale Notification Status Cache on App Relaunch / Resume
*   **Severity:** Medium
*   **Location:** [RootView.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/RootView.swift) in function [RootView.content(board:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/RootView.swift#L51-L96)
*   **Problem:**
    The notification permission check [SettingsViewModel.notificationsAuthorized](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/ViewModels/SettingsViewModel.swift#L517) is cached on app startup inside the `.task` block. If the user suspends the app, opens iOS Settings to toggle notification permissions, and returns to the app, the permission status cache is not refreshed.
*   **Why it matters:**
    The visual warnings in [TaskDetailView](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Task/TaskDetailView.swift#L4) notifying the user that alerts are turned off will display incorrect status.
*   **Suggested fix:**
    Use `@Environment(\.scenePhase) var scenePhase` in [RootView](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/RootView.swift#L4) and add an `.onChange(of: scenePhase)` block. When the phase changes to `.active`, invoke `await settings.refreshNotificationAuthorization()`.

---

## Code Quality Issues

### 6. Missing Verification on Project File References
*   **Severity:** Low
*   **Location:** `task.xcodeproj/project.pbxproj`
*   **Problem:**
    `ManageGroupsView.swift` and `ManageTagsView.swift` have been deleted from the file system. We must verify that their references are fully cleaned up from the `.xcodeproj` file to prevent compiler build warnings or errors. (Note: These files appear to be staged for deletion in Git).
*   **Why it matters:**
    Dangling project files pollute the project structure and cause configuration noise.
*   **Suggested fix:**
    Ensure clean references in the pbxproj file, ensuring the build target resolves correctly.

---

## Performance Issues

### 7. Double Evaluation of groupedResults in SearchView
*   **Severity:** Medium / Low
*   **Location:** [SearchView.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Search/SearchView.swift) in computed property [SearchView.groupedResults](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Search/SearchView.swift#L86)
*   **Explanation:**
    The computed property [groupedResults](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Search/SearchView.swift#L86) is evaluated twice during a single render pass when a query is entered: once for the empty state check (`groupedResults.isEmpty` on line 18) and once in the list container (`ForEach(groupedResults)` on line 26). [groupedResults](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Search/SearchView.swift#L86) performs complex filtering, case-mapping, and sorting across all boards.
*   **Why it matters:**
    Causes redundant CPU work on the main thread, resulting in typing lag in the search bar.
*   **Suggested fix:**
    Compute and assign the result to a local `let` variable inside the `body` view before evaluating the view hierarchy, e.g., `let results = groupedResults`.

---

### 8. Main Thread Blocking during Reset and Seeding
*   **Severity:** Medium
*   **Location:**
    *   [DataImportExport.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/DataImportExport.swift) in function [DataImportExport.resetAll(context:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/DataImportExport.swift#L443-L458)
    *   [SwiftDataManager.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/SwiftDataManager.swift) in function [SwiftDataManager.ensureSeed(context:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/SwiftDataManager.swift#L47-L56)
*   **Explanation:**
    Running a hard reset deletes boards, cancels notifications, and seeds 3 default boards. Each board creation invokes [SwiftDataManager.createBoard(title:subtitle:iconEmoji:into:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/SwiftDataManager.swift#L60-L90), which calls `context.save()` and [UpcomingSnapshotBuilder.writeSnapshot(from:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/UpcomingSnapshotBuilder.swift#L7-L48). This results in 6 database saves and 4 snapshot writes (which involve JSON encoding, disk writes, and widget reloads) synchronously on the `@MainActor`.
*   **Why it matters:**
    Freezes the main thread for several hundred milliseconds. The [ProgressOverlay](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Components/ProgressOverlay.swift) spinner will freeze during this period, giving the appearance of an app hang.
*   **Suggested fix:**
    Batch changes: disable intermediate `context.save()` and [UpcomingSnapshotBuilder.writeSnapshot(from:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/UpcomingSnapshotBuilder.swift#L7-L48) calls during seeding, performing them only once at the end of the entire reset operation.

---

## Missing Tests

### 9. Extremely Low Unit Test Coverage
*   **Severity:** Low
*   **Location:** [TaskTests.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/TaskTests/TaskTests.swift) in class [TaskTests](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/TaskTests/TaskTests.swift#L6)
*   **Problem:**
    The existing test suite only covers color keys, board seeding counts, and date ranges. Key features like multi-board JSON import/export, repeat reminder date-shifting, drag-reorder logic, and widget snapshot serialization are completely uncovered.
*   **Why it matters:**
    Future additions can easily introduce regressions in data migration and core scheduling logic.
*   **Suggested fix:**
    Add unit tests for:
    *   `DataImportExport` JSON payload decoding/encoding (v2 format and v1 fallback).
    *   Reordering index calculation (`placeTask` and reordering delegates).
    *   Repeating rules calculations.
    *   Snapshot file round-trip serialization.

---

## Documentation Issues

### 10. Sync Wording in Developer/User Guides
*   **Severity:** Low
*   **Location:** [README.md](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/README.md)
*   **Problem:**
    Verify user documentation paths and icons (like `archivebox` and `flag.fill`) are perfectly aligned with the newly introduced toolbar icons on the Board Header.
*   **Why it matters:**
    Ensures new users can successfully follow documentation steps.
*   **Suggested fix:**
    Final copy review of guides and update accordingly.

---

## Summary & Priority Action Items

The top issues that should be addressed first are:

1.  **Repeating Reminders Premature Fire (Critical Bug):** Needs immediate fixing to prevent notifications from firing prematurely for future events. See [NotificationService.repeatComponents(rule:base:)](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/NotificationService.swift#L60-L71).
2.  **In-Memory Mutated State on Cancelled Drag (Critical Bug):** Crucial to prevent silent database corruption from aborted drag gestures. See [ColumnView.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Board/ColumnView.swift) and [BoardView.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Board/BoardView.swift).
3.  **Main Thread Block during Reset/Seeding (Performance):** Consolidate database saves and snapshot writes during resetting/seeding to avoid UI freezes. See [DataImportExport.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/DataImportExport.swift) and [SwiftDataManager.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Services/SwiftDataManager.swift).
4.  **Stale Notification Cache (UI/UX):** Keep notification authorizations in sync with scene active phases. See [RootView.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/RootView.swift).
5.  **SearchView Double-Evaluation (Performance):** Cache computed results in a local variable in the body. See [SearchView.swift](file:///Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My%20Drive/Code/Task/Task/Views/Search/SearchView.swift).
