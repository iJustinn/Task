# Issues-cx Review

Review target: current working tree on `task-v0.4.5`.

Validation run during review:

- `rtk xcodebuild -project task.xcodeproj -scheme Task -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/task-review-derived CODE_SIGNING_ALLOWED=NO build` exited 0.
- `rtk xcodebuild -project task.xcodeproj -scheme Task -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/task-review-test-derived CODE_SIGNING_ALLOWED=NO test` exited 0.

This is a SwiftUI/SwiftData iOS task manager. I did not find data-science/model-training code in this project, so the data science categories below are marked not applicable rather than inventing model findings.

## Critical Bugs

### Repeating reminders do not actually keep repeating after a future first occurrence

- **Severity:** High
- **Location:** `Task/Services/NotificationService.swift`, `NotificationService.schedule(for:)`, lines 50-64
- **Problem:** For a repeating task whose reminder anchor is in the future, the code deliberately schedules a non-repeating `UNCalendarNotificationTrigger` and relies on "the next time they open the app (or manual advance + save)" for subsequent occurrences.
- **Why it matters:** The UI exposes Daily / Weekly / Monthly repeat rules, so a user expects the system to continue delivering notifications. A future daily task scheduled for next week will fire once and then stop unless the user returns and manually advances/saves. That is a broken reminder feature, not just a limitation.
- **Suggested fix:** Treat repeating reminders as first-class recurrence. Options: maintain rolling one-shot notifications and reschedule on notification response/app launch/background refresh, schedule multiple upcoming one-shot requests under deterministic identifiers, or redesign the UI to clearly say that repeat only advances dates manually. Add tests around future daily/weekly/monthly reminders.

### Imported data can mutate the in-memory store and notifications before a failed save

- **Severity:** High
- **Location:** `Task/Services/DataImportExport.swift`, `importData(_:context:)` and `mergeBoard(_:into:)`, lines 257-275 and 404-438
- **Problem:** `mergeBoard` mutates SwiftData objects, cancels existing notifications, and schedules imported reminders before the final `context.save()`. If the save throws, `importData` returns `.failure`, but the context has already been changed and notification side effects have already happened.
- **Why it matters:** A failed import can leave the UI showing partially imported data, cancel valid existing reminders, or schedule reminders for data that was not durably saved.
- **Suggested fix:** Make import transactional. Build a side-effect plan while merging, call `context.rollback()` or rebuild from a scratch context on save failure, and only cancel/schedule notifications after a successful save.

### Reset All Data ignores save failures and continues with destructive side effects

- **Severity:** High
- **Location:** `Task/Services/DataImportExport.swift`, `resetAll(context:)`, lines 449-471; `Task/Views/Settings/SettingsView.swift`, `performReset()`, lines 449-455
- **Problem:** Reset cancels notifications, deletes boards, calls `try? context.save()`, clears `task.activeBoardID`, possibly purges persistent files, then reseeds. There is no result or error path if the save fails.
- **Why it matters:** A reset failure can leave partial data loss, stale snapshots, cleared active-board state, or reseeded data mixed with old data, while the UI only shows a progress overlay.
- **Suggested fix:** Return a `Result` from reset, handle `context.save()` errors explicitly, delay irreversible side effects until the delete save succeeds, and show a failure alert when reset cannot complete.

### Import can crash on duplicate group or tag names

- **Severity:** High
- **Location:** `Task/Services/DataImportExport.swift`, `mergeBoard(_:into:)`, lines 321-323 and 353-355
- **Problem:** `Dictionary(uniqueKeysWithValues:)` is built from existing group/tag names lowercased. Swift traps if duplicate keys exist.
- **Why it matters:** Duplicate names can be introduced by old data, manually edited JSON, case-only differences, or a previous import. A user importing a backup should not be able to crash the app with recoverable data quality issues.
- **Suggested fix:** Build dictionaries with an explicit loop that keeps the first match, records duplicates as warnings, and avoids trapping. Normalize and trim names consistently.

## Data Processing Issues

### Date-only fields are stored and exported as full instants

- **Severity:** Medium
- **Location:** `Task/Models/TaskItem.swift`, date fields at lines 10-12; `Task/Components/CalendarPicker.swift`, day selection at lines 269-279; `Task/Services/DataImportExport.swift`, ISO encoding at lines 158-168
- **Problem:** Working and due dates are conceptually date-only, but the model stores `Date` and export uses ISO8601 instants. A local midnight date can shift when exported/imported across time zones or interpreted under a different calendar/time zone.
- **Why it matters:** A task due on May 21 can become May 20 or May 22 for users who travel, change time zones, or import on another device.
- **Suggested fix:** Store date-only values as `DateComponents` or canonical `yyyy-MM-dd` strings in exports, and convert to local display dates at the UI boundary. Add round-trip tests across time zones.

### Tasks imported without a group can become invisible on the board

- **Severity:** Medium
- **Location:** `Task/Services/DataImportExport.swift`, `mergeBoard(_:into:)`, lines 392-402 and 421-432
- **Problem:** When an imported task has `groupID == nil`, `resolvedGroup` is set to nil. New tasks with nil groups are inserted without a group, but `BoardView` renders tasks through each group's `orderedTasks`, so these tasks do not appear in any column.
- **Why it matters:** Importing imperfect or older JSON can create hidden tasks that still exist in storage and search/export, but are not visible in the main workflow.
- **Suggested fix:** Treat missing `groupID` like an orphan and assign the board's fallback group, or surface a clear import warning and provide an "Ungrouped" recovery path.

### Duplicate sort indexes can produce unstable board, group, and task ordering

- **Severity:** Medium
- **Location:** `Task/Models/Board.swift`, `orderedGroups`, lines 33-35; `Task/Models/BoardGroup.swift`, `orderedTasks`, lines 28-29; `Task/Services/DataImportExport.swift`, imported sort indexes at lines 295, 328, 360, 414
- **Problem:** Boards/groups/tasks sort only by `sortIndex`; only tags have a secondary tiebreaker. Import and deletion paths can preserve or create duplicate sort indexes.
- **Why it matters:** Equal sort indexes can make ordering appear unstable across launches, saves, imports, or SwiftData fetch order changes.
- **Suggested fix:** Add deterministic tiebreakers such as `createdAt`/`id`, and normalize sort indexes after import, delete, and reorder operations.

### Deleting a status can assign duplicate sort indexes to moved tasks

- **Severity:** Medium
- **Location:** `Task/Views/Task/StatusPickerSheet.swift`, `deleteGroup(_:)`, lines 247-264; `Task/Views/Board/GroupMenuSheet.swift`, `deleteAndDismiss()`, lines 102-117
- **Problem:** Each moved task gets `sortIndex = (fallback.orderedTasks.last?.sortIndex ?? -1) + 1` inside the loop. Depending on when SwiftData relationship updates are reflected, multiple moved tasks can receive the same next index.
- **Why it matters:** Manual ordering in the fallback column can become nondeterministic after deleting a status with multiple tasks.
- **Suggested fix:** Capture the fallback's current max once, then assign `base + offset + 1` while enumerating moved tasks.

### Board default status can point to a deleted group forever

- **Severity:** Low
- **Location:** `Task/Models/Board.swift`, `defaultGroup` fallback at lines 54-61; `Task/Views/Task/StatusPickerSheet.swift`, `deleteGroup(_:)`, lines 247-264; `Task/Views/Board/GroupMenuSheet.swift`, `deleteAndDismiss()`, lines 102-117
- **Problem:** If the deleted group is the board's `defaultGroupID`, deletion relies on computed fallback behavior but does not update or clear the stored ID.
- **Why it matters:** The app works by falling back, but exports preserve a stale default group ID and the setting is internally inconsistent.
- **Suggested fix:** When deleting a group, if `board.defaultGroupUUID == group.id`, set it to the chosen fallback group's ID before saving.

## Model / Data Science Issues

### No model-training or prediction pipeline is present

- **Severity:** Low
- **Location:** Project-wide
- **Problem:** The requested review categories include model training, feature engineering, prediction, and evaluation, but this repository contains a local-first iOS app with no ML/data-science pipeline.
- **Why it matters:** There is no model reproducibility, training-data leakage, or evaluation logic to review. Treating the app as a modeling project would create false findings.
- **Suggested fix:** No implementation change needed. If ML features are added later, introduce separate modules for data collection consent, feature extraction, model versioning, evaluation, and deterministic tests.

## UI / Dashboard Issues

### App asks for notification permission on launch instead of when the user opts into reminders

- **Severity:** High
- **Location:** `Task/Views/RootView.swift`, `content(board:)`, lines 99-101; `Task/Views/Settings/AboutSheets.swift`, privacy copy at lines 337-343
- **Problem:** `RootView` calls `NotificationService.requestAuthorizationIfNeeded()` in `.task` as soon as the main content appears. The privacy copy says permission is requested only to deliver reminders the user opts into.
- **Why it matters:** Early permission prompts reduce opt-in rates and contradict the app's stated privacy behavior. A user can be asked for notifications before creating any task or enabling any reminder.
- **Suggested fix:** Request permission the first time the user enables Reminder or saves a task with reminders on. Keep the launch-time status refresh, but remove the launch-time permission request.

### Past one-shot reminders can display as enabled even though no notification is scheduled

- **Severity:** Medium
- **Location:** `Task/Services/NotificationService.swift`, past-date guard at lines 30-33; `Task/Views/Task/TaskDetailView.swift`, save path at lines 498-508; `Task/Views/Board/TaskCardView.swift`, alarm footer at lines 51-55
- **Problem:** For non-repeating reminders whose resolved fire date is in the past, `NotificationService.schedule` returns without scheduling. The saved task still has `hasReminder == true`, so the editor/card show an alarm.
- **Why it matters:** The UI says a reminder exists when there is no pending notification.
- **Suggested fix:** Disable reminders for past non-repeating dates, clear `hasReminder` on save when scheduling is skipped, or show an explicit "date is in the past" warning before saving.

### Working-range reminders use the end date, while the UI implies the working row as a whole

- **Severity:** Medium
- **Location:** `Task/Models/TaskItem.swift`, `primaryReminderDate`, lines 50-55; `Task/Views/Task/TaskDetailView.swift`, `reminderAnchor`, lines 47-57
- **Problem:** If a task has only a working range and no due date, `primaryReminderDate` returns `workingEnd ?? workingStart`, so reminders fire at the end of the range. The editor only marks the Working row, not the specific end date.
- **Why it matters:** Users commonly expect a "working" reminder to fire when work starts. For a week-long working range, the notification may arrive at the end of the week.
- **Suggested fix:** Decide and document the intended anchor. If it should be start-of-work, change `primaryReminderDate` to prefer `workingStart`. If end-of-work is intended, label the UI accordingly and add a test.

### Upcoming widget ignores near-term working starts when a later due date exists

- **Severity:** Medium
- **Location:** `Task/Services/UpcomingSnapshotBuilder.swift`, snapshot date choice at lines 15-17; `TaskWidgetExtension/WidgetSnapshot.swift`, `primaryDate`, lines 34-36
- **Problem:** The widget chooses `dueDate ?? workingEnd ?? workingStart`. A task with `workingStart` tomorrow and `dueDate` next month is excluded from the seven-day widget because the later due date wins.
- **Why it matters:** The widget can miss tasks that are upcoming from a work-start perspective.
- **Suggested fix:** Use the earliest relevant date for inclusion/sorting, or include both working and due dates and render the nearest one. Align this with `TaskItem.primaryReminderDate` semantics.

### Repeat row has a smaller tap target than the other property rows

- **Severity:** Low
- **Location:** `Task/Views/Task/TaskDetailView.swift`, `repeatRow`, lines 306-335
- **Problem:** Status, Tags, Working, and Due rows are full-row buttons. Repeat only wraps the value chip/empty label in a button; tapping the icon/label area does nothing.
- **Why it matters:** This is inconsistent with the editor's property-list interaction pattern and makes Repeat harder to discover.
- **Suggested fix:** Make the whole Repeat property row open `RepeatPickerSheet`, with the advance button kept as a separate trailing control.

### Search behavior and documentation disagree about search scope

- **Severity:** Low
- **Location:** `Task/Views/Search/SearchView.swift`, all-board search at lines 90-117; `README.md`, Highlights section; `Task/Views/Search/SearchView.swift`, empty-state copy at lines 16-21
- **Problem:** The implementation and empty state say search runs across all boards. The README says search finds tasks "across the active board."
- **Why it matters:** Users and future maintainers will not know whether cross-board search is intentional.
- **Suggested fix:** Pick one behavior and align README, in-app copy, and tests.

## Code Quality Issues

### Many persistence operations silently discard errors

- **Severity:** Medium
- **Location:** Examples include `SwiftDataManager.ensureSeed` line 84, `SwiftDataManager.createBoard` line 120, `TaskDetailView.save` line 502, `TaskDetailView.delete` line 535, `ProjectHeaderView.commit` line 131, `BoardSwitcherView.deleteBoard` line 202, `StatusPickerSheet.addGroup/deleteGroup` lines 241 and 262, `TagPickerSheet.addTag/deleteTag` lines 250 and 259
- **Problem:** The app uses `try? context.save()` broadly. Failed saves generally leave no user-visible error and can still trigger snapshots or notification changes.
- **Why it matters:** Local persistence is the app's core promise. Silent failure risks data loss or UI/snapshot drift that users cannot understand or recover from.
- **Suggested fix:** Centralize saves in a small helper that logs errors and returns a user-facing result for destructive or user-initiated actions. Only write snapshots/notifications after confirmed saves.

### SwiftData fallback still has a force-try crash path

- **Severity:** Medium
- **Location:** `Task/Services/SwiftDataManager.swift`, `makeModelContainer()`, lines 20-35
- **Problem:** If the persistent container fails, the app falls back to an in-memory container using `try!`.
- **Why it matters:** If in-memory container creation also fails, the app crashes before showing any recovery UI. This is rare, but it is the worst moment to crash because the persistent store is already unhealthy.
- **Suggested fix:** Handle the second failure explicitly. Show a minimal fatal recovery screen or log/report the failure with actionable instructions instead of `try!`.

### Date formatting uses a global mutable `DateFormatter`

- **Severity:** Medium
- **Location:** `Task/Utils/DateFormatters.swift`, `TaskDateFormat.locale` and `medium`, lines 3-22; `Task/ViewModels/SettingsViewModel.swift`, language didSet at lines 484-488
- **Problem:** `TaskDateFormat` mutates a static `DateFormatter` through `nonisolated(unsafe)`. `DateFormatter` is not designed for unsynchronized cross-thread mutation/use.
- **Why it matters:** Most calls are currently UI/main-actor, but services also call date formatting. Future background use can introduce racey or inconsistent formatting.
- **Suggested fix:** Make formatting main-actor isolated, create formatters per locale through a locked/cache helper, or use value-style `Date.FormatStyle` with explicit locale.

### Drag-and-drop live reordering mutates SwiftData before a committed drop

- **Severity:** Medium
- **Location:** `Task/Views/Board/ColumnView.swift`, `dropEntered(info:)`, lines 219-229; `Task/Views/Board/BoardView.swift`, `placeTask(_:in:atIndex:commit:)`, lines 69-107 and rollback lines 110-154
- **Problem:** Hovering during drag mutates real `TaskItem` relationships/sort indexes with `commit: false`; rollback depends on a watchdog that fires after five seconds of no drag events.
- **Why it matters:** During those five seconds, the model is dirty. Autosave, backgrounding, an unrelated save, or a missed watchdog can persist a move the user did not drop.
- **Suggested fix:** Keep live drag ordering in view state and mutate SwiftData only on `performDrop`, or add an explicit immediate rollback path for background/drop-cancel events and disable autosave for these speculative mutations.

### Group/tag/board drag-delete implementations are duplicated

- **Severity:** Low
- **Location:** `Task/Views/Board/BoardSwitcherView.swift`, `Task/Views/Task/StatusPickerSheet.swift`, `Task/Views/Task/TagPickerSheet.swift`
- **Problem:** The drag-to-delete zone, hover debouncing, haptics, and drop cleanup are implemented three times with similar but separate code.
- **Why it matters:** Bugs and fixes can drift between boards, statuses, and tags. The current code already has separate delete/reorder delegates with subtle differences.
- **Suggested fix:** Extract a generic reusable drag-delete zone/delegate helper once the behavior stabilizes.

## Performance Issues

### Search performs full in-memory filtering and sorting on every keystroke

- **Severity:** Medium
- **Location:** `Task/Views/Search/SearchView.swift`, `groupedResults`, lines 90-103
- **Problem:** Each render trims/lowercases the query, scans every task in every board, lowercases multiple fields, scans tags, and sorts each matching board's tasks on the main thread.
- **Why it matters:** This will become typing lag as task count grows, especially because search is driven directly by a focused text field.
- **Suggested fix:** Debounce search input, maintain normalized searchable text on each task, move filtering into a view model, and consider a SwiftData predicate/fetch for large datasets.

### Board columns sort and allocate repeatedly during render and drag

- **Severity:** Medium
- **Location:** `Task/Views/Board/ColumnView.swift`, `currentTasks`, lines 24-26; body usage at lines 39-64; drop delegate index helpers at lines 203-213
- **Problem:** `currentTasks` sorts every time it is read, then the body creates arrays from prefixes and the drop delegate repeatedly calls `targetGroup.orderedTasks` during drag.
- **Why it matters:** Drag and scroll performance will degrade with large columns because sorting/allocation happens on the main thread during high-frequency UI updates.
- **Suggested fix:** Compute sorted visible tasks once per render, pass the ordered list to delegates where possible, and cache/manual-normalize order at the model/view-model level for large boards.

### Widget reloads are triggered broadly and synchronously after many saves

- **Severity:** Low
- **Location:** `Task/Services/UpcomingSnapshotBuilder.swift`, `writeSnapshot(from:)`, lines 7-48; callers throughout task, board, import, reset, and settings flows
- **Problem:** Snapshot writing fetches all tasks and boards, encodes JSON, writes shared defaults, and calls `WidgetCenter.shared.reloadAllTimelines()` every time.
- **Why it matters:** Frequent small edits can repeatedly reload widget timelines and do full scans, which is unnecessary for changes that do not affect upcoming widget content.
- **Suggested fix:** Debounce snapshot writes, skip reloads for changes that cannot affect the widget, and consider a narrower fetch/predicate for the next seven days.

## Missing Tests

### Test suite is too small for the app's core behavior

- **Severity:** High
- **Location:** `TaskTests/TaskTests.swift`, lines 13-41
- **Problem:** The test target has only three tests: seed creation, working range detection, and color key round-trip.
- **Why it matters:** The highest-risk features have no automated coverage: import/export merge, reset, notifications, repeat rules, board defaults, widget snapshot encoding, localization, and drag ordering.
- **Suggested fix:** Add focused unit tests for import/export round trips, legacy import, orphan handling, reset behavior, notification trigger decisions, repeat advancement, widget snapshot date selection, and group/tag deletion sorting.

### No tests cover notification scheduling decisions

- **Severity:** High
- **Location:** `Task/Services/NotificationService.swift`; no corresponding tests in `TaskTests/TaskTests.swift`
- **Problem:** Reminder behavior includes date anchoring, past-date skipping, repeat rules, board reminder times, authorization status, and cancellation, but no tests exercise these branches.
- **Why it matters:** Notification bugs are hard to catch manually and have high user impact.
- **Suggested fix:** Extract pure scheduling-decision logic into a testable helper that returns trigger components/repeat flags, then test none/daily/weekly/monthly, past/today/future anchors, working ranges, and board reminder times.

### No tests cover import failure rollback or notification side effects

- **Severity:** Medium
- **Location:** `Task/Services/DataImportExport.swift`; no corresponding tests in `TaskTests/TaskTests.swift`
- **Problem:** Import mutates data and notifications in multiple steps, but tests only cover initial seed data.
- **Why it matters:** Import is a recovery/backup path. Bugs here can lose data or reminders.
- **Suggested fix:** Add import tests for invalid JSON, duplicate group/tag names, missing groups/tags, failed save rollback, legacy v1 payloads, and notification cancellation/scheduling after successful imports.

## Documentation Issues

### Several Simplified Chinese localizations are missing for new strings

- **Severity:** Medium
- **Location:** `Task/Localizable.xcstrings`, examples at lines 408, 632, 1070, 1611, 1694, 1744, 1977, 2426; source references in `Task/Views/Board/ColumnView.swift`, lines 146-151 and `Task/ViewModels/SettingsViewModel.swift`, lines 310 and 319
- **Problem:** Eight source strings have no `zh-Hans` localization, including column empty states and the new Extra Large/Spacious text-size labels.
- **Why it matters:** Users who select Simplified Chinese will see mixed English/Chinese UI in common empty states and settings.
- **Suggested fix:** Add `zh-Hans` translations for all eight missing entries and run localization extraction/validation.

### String catalog contains many stale entries

- **Severity:** Low
- **Location:** `Task/Localizable.xcstrings`, examples include stale `Customization` at lines 672-681, `Date range` at lines 717-726, `Due` at lines 946-956, `No tags yet` at lines 1588-1597, `Reminder` at lines 1808-1818
- **Problem:** The string catalog has about 60 entries marked `extractionState: "stale"`.
- **Why it matters:** Stale strings increase translator workload and make it harder to spot missing active translations.
- **Suggested fix:** Prune stale entries after confirming they are no longer referenced, or keep them with a documented reason if they are intentionally retained.

### Version history references deleted settings files and older behavior

- **Severity:** Low
- **Location:** `VersionHistory.md`, toolbar section around line 83 and tag sort section around line 141
- **Problem:** The docs still mention `ManageGroupsView` and `ManageTagsView`, but those files are deleted in the current working tree. The same history also describes older settings organization that has since moved into task/status/tag picker flows.
- **Why it matters:** Maintainers reading release notes will look for files and flows that no longer exist.
- **Suggested fix:** Update the 0.4.5 history to describe the current files and flows, or keep older notes under their original version without implying they are current.

### README screenshots and some copy lag behind the current version

- **Severity:** Low
- **Location:** `README.md`, screenshots at lines 14-21; search and board-switcher copy in Highlights
- **Problem:** The README says the app version is 0.4.5 but still links v0.4.0 screenshots. It also says search is across the active board while current implementation searches all boards.
- **Why it matters:** Screenshots and feature descriptions are part of release confidence. Outdated docs can lead to incorrect QA expectations.
- **Suggested fix:** Refresh screenshots for v0.4.5 and align the search/board-switcher wording with the current UI.

### Privacy copy conflicts with actual notification-permission timing

- **Severity:** Medium
- **Location:** `Task/Views/Settings/AboutSheets.swift`, privacy notification copy at lines 337-343; `Task/Views/RootView.swift`, launch prompt at lines 99-101
- **Problem:** Privacy text says notification permission is requested only for reminders the user opts into, but the app requests permission on main content launch.
- **Why it matters:** Privacy wording must match behavior.
- **Suggested fix:** Prefer fixing the behavior by moving the permission request to the reminder opt-in flow; otherwise update the privacy copy.

## Configuration / Dependency Issues

### No CI workflow is present for build and test verification

- **Severity:** Low
- **Location:** Project root; no `.github/workflows` directory found
- **Problem:** Build and test are manual only.
- **Why it matters:** The project can regress buildability, tests, asset catalogs, localization, or privacy manifests without automated checks on push/PR.
- **Suggested fix:** Add a GitHub Actions workflow that runs `xcodebuild test` on an available simulator and lints the project file/string catalog JSON.

### Swift strict concurrency checking is not enabled

- **Severity:** Low
- **Location:** `task.xcodeproj/project.pbxproj`, build settings around lines 473, 510, 539, 568, 591, 615
- **Problem:** The project uses Swift 5 mode and does not set stricter concurrency checking, while code has global mutable state (`TaskDateFormat`) and async/main-actor boundaries.
- **Why it matters:** Concurrency issues can hide until a future Swift language mode or deployment target change.
- **Suggested fix:** Gradually enable `SWIFT_STRICT_CONCURRENCY` warnings in Debug and address surfaced issues before moving to Swift 6 language mode.

## Summary / Fix Priority

1. **Fix reminder correctness first:** repeating reminders, past one-shot reminders, notification permission timing, and the working-range anchor are user-visible trust issues.
2. **Make import/reset transactional:** defer notification side effects until save success, rollback on failure, avoid duplicate-name crashes, and surface reset errors.
3. **Stabilize date and ordering models:** use date-only persistence for date-only fields and normalize/tie-break sort indexes.
4. **Improve coverage:** add tests for notifications, import/export/reset, widget snapshot dates, and deletion/reorder edge cases.
5. **Clean user-facing polish:** fill missing Chinese translations, update stale docs/screenshots, and align privacy/search copy with behavior.
