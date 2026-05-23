# Issues-cx Review

Review target: current working tree on branch `task-v0.4.6`.

Validation run during review:

- `test_sim` through XcodeBuildMCP succeeded: 7 passed, 0 failed.

This repository is a SwiftUI/SwiftData iOS task manager with a WidgetKit extension. I did not find data-science feature engineering, model training, evaluation, or prediction code; those categories are marked not applicable instead of inventing model-specific findings.

## Critical Bugs

### Task save/delete can change notifications and widget state even if persistence fails

- **Severity:** High
- **Location:** `Task/Views/Task/TaskDetailView.swift`, `save()` and `delete()`
- **Problem:** `save()` mutates or inserts a `TaskItem`, calls `try? context.save()`, then schedules/cancels notifications and writes the widget snapshot regardless of whether the save succeeded. `delete()` cancels notifications before `context.delete(task)` and also ignores `context.save()` failure.
- **Why it matters:** A failed save can leave the UI dismissed while the task was not durably saved, or can schedule/cancel notifications and update the widget for state that did not commit. Delete failure is worse: the reminder can be cancelled even though the task remains in storage.
- **Suggested fix:** Use `do/catch` around `context.save()`. Only schedule/cancel notifications, update snapshots, and dismiss after a successful save. For delete, save the deletion first, then cancel notifications, or keep a recovery path that reschedules if save fails.

### Import failure leaves mutated SwiftData objects in the live context

- **Severity:** High
- **Location:** `Task/Services/DataImportExport.swift`, `importData(_:context:)` and `mergeBoard(_:into:plan:)`
- **Problem:** Import mutates existing boards, groups, tags, and tasks before the final `context.save()`. If `context.save()` throws, the method returns `.failure`, but it does not roll back the already-mutated `ModelContext`.
- **Why it matters:** A user can see partial imported state after an "Import Failed" alert, and a later unrelated save can persist those partial mutations. The notification plan is correctly delayed, but the data mutations are still live.
- **Suggested fix:** Validate and stage imports in a scratch/in-memory context, then apply to the real context only after validation succeeds. At minimum, call `context.rollback()` on save failure and add tests that force save failure or invalid payload recovery.

### Drag reorder mutates persistent models before the user drops

- **Severity:** High
- **Location:** `Task/Views/Board/BoardView.swift`, `placeTask(_:in:atIndex:commit:)`; `Task/Components/ReorderDropDelegate.swift`, `dropEntered(info:)`
- **Problem:** Task, board, status, and tag reordering mutates real `sortIndex` / relationship state during hover. Task-card dragging has a five-second rollback watchdog; board/status/tag `ReorderDropDelegate` has no rollback at all if the drag is cancelled outside a valid drop target.
- **Why it matters:** SwiftData objects are dirty before the gesture commits. Autosave, backgrounding, another explicit save, or a missed cleanup path can persist a reorder the user never dropped.
- **Suggested fix:** Keep speculative drag order in view state and write SwiftData only in `performDrop`. If live model mutation is kept, add explicit rollback on cancel/background for all reorderable types and automated tests around cancelled drags.

### Repeating reminders still have a finite delivery window

- **Severity:** High
- **Location:** `Task/Services/NotificationService.swift`, `repeatBatchSize` and `schedule(for:)`; `Task/Views/RootView.swift`, `refreshRepeatReminders()`
- **Problem:** A repeating reminder schedules 16 one-shot notifications. The batch is refreshed on app launch / scene active, but if the user does not open the app before the batch runs out, daily/weekly/monthly reminders stop.
- **Why it matters:** The UI exposes repeat rules as ongoing behavior. A daily reminder that silently stops after 16 days without app activation is a broken expectation for reminders.
- **Suggested fix:** Either document this limitation clearly, or implement rolling rescheduling via notification response handling, background refresh where available, and/or scheduling the maximum allowed future occurrences across active repeating tasks with deterministic refresh logic.

## Data Processing Issues

### Date-only task fields are stored and exported as absolute instants

- **Severity:** Medium
- **Location:** `Task/Models/TaskItem.swift`, `workingStart`, `workingEnd`, `dueDate`; `Task/Services/DataImportExport.swift`, JSON encoder/decoder date strategy
- **Problem:** Working and due dates are date-only concepts in the UI, but the app stores them as `Date` and exports them as ISO8601 instants.
- **Why it matters:** Midnight-local `Date` values can shift calendar days when a user changes time zone, travels, or imports/export data on another device with a different time zone.
- **Suggested fix:** Store/export date-only values as `yyyy-MM-dd` or a small `DateComponents` payload. Convert to local `Date` only at UI/scheduling boundaries. Add round-trip tests across time zones.

### Import can still crash if duplicate task IDs exist in a board

- **Severity:** Medium
- **Location:** `Task/Services/DataImportExport.swift`, `mergeBoard(_:into:plan:)`, `tasksByID`
- **Problem:** `Dictionary(uniqueKeysWithValues: existingTasks.map { ($0.id, $0) })` traps if a board already contains duplicate `TaskItem.id` values. The model does not enforce unique IDs with SwiftData attributes.
- **Why it matters:** A malformed backup, old migration bug, or manual JSON edit can turn import into a crash instead of a recoverable data-quality warning.
- **Suggested fix:** Build the dictionary with a first-wins loop, count duplicates as import warnings, and consider a repair pass that regenerates duplicate IDs before merge.

### Reset reports success even if reseeding fails

- **Severity:** Medium
- **Location:** `Task/Services/DataImportExport.swift`, `resetAll(context:)`; `Task/Services/SwiftDataManager.swift`, `ensureSeed(context:)`
- **Problem:** `resetAll` returns `true` after calling `SwiftDataManager.ensureSeed`, but `ensureSeed` swallows its seed `context.save()` error with `try?`.
- **Why it matters:** Reset can delete existing data successfully, fail to create/save the default boards, and still report success to the UI.
- **Suggested fix:** Make `ensureSeed` return a success/failure result or throw. Have `resetAll` surface reseed failure and avoid writing a success snapshot when defaults did not commit.

### `workingRange` handles reversed imported ranges differently from other date logic

- **Severity:** Low
- **Location:** `Task/Models/TaskItem.swift`, `workingRange`
- **Problem:** `workingRange` returns `start...max(end, start)`, collapsing a reversed imported range to a single-day range. Other logic, such as `matchesDateFilter`, normalizes reversed bounds with `min`/`max`.
- **Why it matters:** The property is currently unused, but if future code relies on it, imported or malformed reversed ranges will behave inconsistently across features.
- **Suggested fix:** Either delete the unused property or normalize both lower and upper bounds with `min(start, end)` and `max(start, end)`, matching `matchesDateFilter`.

## Model / Data Science Issues

### No model-training or prediction pipeline is present

- **Severity:** Low
- **Location:** Project-wide
- **Problem:** The requested review scope includes model training, feature engineering, prediction, and evaluation code, but this repository does not contain an ML or data-science pipeline.
- **Why it matters:** There are no model reproducibility, train/test leakage, evaluation, or feature-engineering concerns to audit.
- **Suggested fix:** No app change required. If ML features are added later, introduce explicit modules for data consent, feature extraction, model versioning, evaluation, and deterministic tests.

## UI / Dashboard Issues

### Widget copy says reminders, but widget data includes all dated tasks

- **Severity:** Medium
- **Location:** `TaskWidgetExtension/UpcomingTasksWidget.swift`, widget description; `Task/Services/UpcomingSnapshotBuilder.swift`, `writeSnapshot(from:)`
- **Problem:** The widget description says "See your next tasks with reminders set", but the snapshot builder includes any task with a working or due date, regardless of `hasReminder`.
- **Why it matters:** Users may expect the widget to be a reminder dashboard, while the implementation is an upcoming-date dashboard. This mismatch causes confusion and makes future behavior ambiguous.
- **Suggested fix:** Decide whether the widget is for dated tasks or reminders. If it is dated tasks, update widget copy. If it is reminders, filter `allTasks` by `hasReminder`.

### Widget excludes active working ranges that started before today

- **Severity:** Medium
- **Location:** `Task/Services/UpcomingSnapshotBuilder.swift`, `earliestDate(_:)` and window filter
- **Problem:** The snapshot uses the earliest of `workingStart`, `workingEnd`, and `dueDate` for inclusion. A task with `workingStart` yesterday and `workingEnd` tomorrow gets excluded because the earliest date is before `windowStart`, even though the task is active today and still inside the next seven days.
- **Why it matters:** Ongoing work ranges can disappear from the widget during the period when the user most needs them visible.
- **Suggested fix:** For working ranges, include the task if the range overlaps the widget window. Use the nearest relevant date for sorting/rendering, not simply the earliest stored date.

### Confirmation sheets can clip at larger text sizes or longer localizations

- **Severity:** Medium
- **Location:** `Task/Components/ConfirmationSheet.swift`, `confirmationSheetPresentationStyle()`
- **Problem:** All confirmation sheets use a fixed `.height(360)` detent while the content uses dynamic type and localized strings. Longer board/tag/status names and larger text settings can exceed the fixed sheet height.
- **Why it matters:** Destructive confirmations must remain readable and tappable. Clipped copy or buttons can make delete flows unsafe or unusable.
- **Suggested fix:** Use adaptive content height when possible, add a scroll container inside the confirmation sheet, or provide multiple detents such as `.height(360), .medium` with enough vertical flexibility for large text.

### Task editor still uses fixed numeric font sizes for key fields

- **Severity:** Medium
- **Location:** `Task/Views/Task/TaskDetailView.swift`, `taskTitleFontSize`, `propertyFontSize`, `chipFontSize`, `titleField`, `propertyRow`, `taskDetailChip`
- **Problem:** The editor hard-codes font sizes with `.system(size:)` for title, property labels, and chips. The view applies `.dynamicTypeSize(settings.textSize.dynamicType)`, but fixed-size fonts do not scale like semantic text styles.
- **Why it matters:** The app has a Text Size setting, but parts of the most important editor screen can remain visually out of sync or inaccessible at larger sizes.
- **Suggested fix:** Use semantic fonts (`.title2`, `.body`, `.headline`) with weights/designs, or wrap fixed sizes in `@ScaledMetric(relativeTo:)` and audit every fixed-size text surface.

### Board title cannot be cleared once it has a non-empty value

- **Severity:** Low
- **Location:** `Task/Views/Board/ProjectHeaderView.swift`, `commit()`
- **Problem:** The commit path only writes the title when the trimmed title is non-empty. If a user deletes a board title and leaves the field, the old title remains.
- **Why it matters:** New boards are allowed to start with an empty title, so existing boards should either support clearing or the UI should prevent clearing consistently.
- **Suggested fix:** Decide whether empty board titles are allowed. If yes, save empty titles and rely on "Untitled" display fallback. If no, disable empty titles in the editor and restore draft text visibly.

## Code Quality Issues

### Persistence errors are broadly swallowed with `try?`

- **Severity:** Medium
- **Location:** Project-wide examples: `SwiftDataManager.ensureSeed`, `SwiftDataManager.createBoard`, `ProjectHeaderView.commit`, `BoardSwitcherView.deleteBoard`, `GroupMenuSheet.save/deleteAndDismiss`, `StatusPickerSheet.addGroup/deleteGroup`, `TagPickerSheet.addTag/deleteTag`, `TaskDetailView.save/delete`
- **Problem:** User-initiated writes commonly call `try? context.save()` and then proceed as if the operation succeeded.
- **Why it matters:** SwiftData persistence is the app's core data layer. Silent save failure can cause data loss, stale UI, incorrect widget snapshots, or notification drift without any user-visible recovery path.
- **Suggested fix:** Introduce a small `PersistenceController.save(context:operation:)` helper that logs and returns a result. Use explicit error handling for destructive writes and any write followed by notifications or widget updates.

### SwiftData fallback has a force-try crash path

- **Severity:** Medium
- **Location:** `Task/Services/SwiftDataManager.swift`, `makeModelContainer()`
- **Problem:** If opening the persistent store fails, the app falls back to an in-memory store with `try! ModelContainer(...)`.
- **Why it matters:** The persistent store is already in a failure state at this point. If in-memory container creation also fails, the app crashes before presenting any recovery UI.
- **Suggested fix:** Handle the second failure explicitly. Show a minimal fatal recovery state, log the error, and avoid `try!` in launch-critical code.

### Global mutable `DateFormatter` state is marked `nonisolated(unsafe)`

- **Severity:** Medium
- **Location:** `Task/Utils/DateFormatters.swift`, `TaskDateFormat.locale`, `currentStyle`, `medium`, `styledFormatters`
- **Problem:** Locale and date-format style are stored in global mutable static state, including mutable `DateFormatter` instances. The code marks this state `nonisolated(unsafe)`.
- **Why it matters:** `DateFormatter` is not safe to mutate/read concurrently. The current app is mostly main-actor, but services and notifications already use formatting outside view code, and future background work can produce racey or inconsistent dates.
- **Suggested fix:** Move date formatting behind a main-actor service, use value-style `Date.FormatStyle`, or protect formatter caching with a lock/actor.

### Notification scheduling ignores system-level add failures

- **Severity:** Medium
- **Location:** `Task/Services/NotificationService.swift`, `schedule(for:)`
- **Problem:** `UNUserNotificationCenter.add(_:withCompletionHandler:)` is called with `nil`, so failures from denied authorization, too many pending notifications, invalid triggers, or system errors are discarded.
- **Why it matters:** The task can show `hasReminder == true` even when no notification was actually scheduled.
- **Suggested fix:** Use the completion handler or async notification APIs, return a schedule result, and surface failures in the task editor. Add tests around pending request identifiers where possible.

### App Group read/write failures are silent

- **Severity:** Low
- **Location:** `Task/Services/SharedDefaultsService.swift`; `TaskWidgetExtension/WidgetSnapshot.swift`
- **Problem:** Shared defaults reads and writes return empty/default values on any error. Encoding and decoding failures are ignored.
- **Why it matters:** Widget configuration and upcoming snapshots can silently disappear if App Group setup, encoding, or decoding breaks.
- **Suggested fix:** Log failures with `Logger`, include snapshot schema/version fields, and consider a lightweight debug indicator for missing App Group data during development.

## Performance Issues

### Search scans and lowercases every task on every keystroke

- **Severity:** Medium
- **Location:** `Task/Views/Search/SearchView.swift`, `groupedResults`
- **Problem:** Each render trims/lowercases the query, scans every task in every board, lowercases title/notes/group/tag fields, and sorts matches on the main thread.
- **Why it matters:** This will become typing lag as task count grows, especially while the search text field is focused and updating continuously.
- **Suggested fix:** Debounce search input, move filtering into a view model, cache normalized searchable text per task, and consider SwiftData predicates for large datasets.

### Date slider materializes every day between earliest and latest task date

- **Severity:** Medium
- **Location:** `Task/Views/Board/BoardView.swift`, `BoardDateSliderDayWindow.dates(for:target:fallback:calendar:)`
- **Problem:** The slider now correctly derives its bounds from task dates, but it creates an array and tile identity for every day between the minimum and maximum dates.
- **Why it matters:** One old task and one far-future task can create thousands of dates, increasing memory, diffing work, and horizontal scroll cost.
- **Suggested fix:** Keep min/max as logical bounds but page/virtualize dates around the visible region. Alternatively, generate months/days lazily or warn/repair unusually large date spans.

### Board columns repeatedly sort and allocate during rendering and drag

- **Severity:** Medium
- **Location:** `Task/Views/Board/ColumnView.swift`, `currentTasks`, body, and `TaskRowDropDelegate` index helpers; `Task/Models/BoardGroup.swift`, `sortedTasks`
- **Problem:** Columns sort tasks whenever `currentTasks` is read, allocate `Array(ordered.prefix(...))`, and drop delegates repeatedly call `targetGroup.orderedTasks` during drag.
- **Why it matters:** Sorting and allocation on the main thread during drag/scroll can cause jank on large boards.
- **Suggested fix:** Compute ordered/filtered tasks once per render, pass the ordered list into delegates, and normalize manual order in the model after mutations so sorting work is minimized.

### Widget snapshots fetch all tasks and reload every timeline after many saves

- **Severity:** Low
- **Location:** `Task/Services/UpcomingSnapshotBuilder.swift`, `writeSnapshot(from:)`
- **Problem:** Snapshot writing fetches every task and board, encodes JSON, writes shared defaults, and calls `WidgetCenter.shared.reloadAllTimelines()` after many ordinary save operations.
- **Why it matters:** Frequent edits can cause unnecessary main-thread work and widget reload churn, even for changes that do not affect upcoming widget content.
- **Suggested fix:** Debounce snapshot writes, skip reloads when a change cannot affect the widget, and use narrower fetch predicates for the next seven days.

## Missing Tests

### Core persistence and side-effect flows are not tested

- **Severity:** High
- **Location:** `TaskTests/TaskTests.swift`
- **Problem:** The test suite has seven tests covering seed defaults, date filtering, color keys, and text-size defaults. It does not cover task save/delete, failed saves, notification scheduling/cancellation, widget snapshot content, board/status/tag delete, reset, or import/export merge behavior.
- **Why it matters:** The riskiest flows combine SwiftData mutations with notifications and widget side effects. Regressions in these flows can pass the current suite.
- **Suggested fix:** Add in-memory SwiftData tests for save/delete/reset/import, inject notification and widget writer protocols for side-effect assertions, and add tests for save-failure paths.

### Drag reorder behavior has no automated coverage

- **Severity:** Medium
- **Location:** `Task/Views/Board/BoardView.swift`, `Task/Components/ReorderDropDelegate.swift`, picker sheets
- **Problem:** Reorder behavior is implemented through SwiftUI drag/drop delegates, but there are no tests for committed moves, cancelled moves, cross-column moves, or non-manual sort behavior.
- **Why it matters:** Drag reorder has already been a source of freezes and state bugs. It also mutates persistent model state, making regressions high impact.
- **Suggested fix:** Extract reorder calculations into pure functions and unit test them. Add UI tests or simulator-driven regression checks for drag cancellation and successful drops.

### Widget logic is not covered by tests

- **Severity:** Medium
- **Location:** `Task/Services/UpcomingSnapshotBuilder.swift`, `TaskWidgetExtension/*`
- **Problem:** There are no tests that verify which tasks enter the widget snapshot, how board filtering behaves, or how date ranges are rendered.
- **Why it matters:** Widget behavior can drift from app behavior without being caught, especially because the widget has duplicate Codable structs.
- **Suggested fix:** Move snapshot selection into a pure helper shared by app tests, and add tests for due dates, working ranges, active ranges, board filtering, and empty snapshots.

## Configuration / Dependency Issues

### Project is Xcode-only with no CI or reproducible command documented

- **Severity:** Low
- **Location:** Project root / repository configuration
- **Problem:** The README tells contributors to open Xcode, but there is no CI workflow or documented command-line test/build invocation.
- **Why it matters:** Whole-project regressions depend on manual local testing. This is easy to skip and makes release readiness less reproducible.
- **Suggested fix:** Add a minimal GitHub Actions workflow or documented `xcodebuild` command for simulator build/test, including the intended simulator/device target.

### Default signing team is committed in tracked config

- **Severity:** Low
- **Location:** `Config/Signing.xcconfig`
- **Problem:** The tracked config includes a concrete `DEVELOPMENT_TEAM` value.
- **Why it matters:** This is not a secret, but it makes contributor builds target the maintainer's team by default and can be surprising in a public/source-available repo.
- **Suggested fix:** Leave `DEVELOPMENT_TEAM` empty in the tracked file and rely on `Signing.local.xcconfig` for local team IDs, or clearly document that the tracked value is intentional for maintainer builds.

## Documentation Issues

### README points to an old Settings section name

- **Severity:** Low
- **Location:** `README.md`, Highlights -> Local reminders
- **Problem:** The README says reminder time is under `Settings -> Default -> Reminder Time`, but the app now places it under `Settings -> Board -> Reminder Time`.
- **Why it matters:** New users and maintainers following the README will look in the wrong place.
- **Suggested fix:** Update the README path to match the current Settings layout.

### Lessons learned still references older Settings card patterns

- **Severity:** Low
- **Location:** `LessonsLearned.md`, "Settings card UI" and older UI notes
- **Problem:** Several lessons describe prior card-heavy patterns that have since been redesigned into flat picker rows and full-screen/sheet surfaces.
- **Why it matters:** Future implementation work may follow stale internal guidance and reintroduce old UI structure.
- **Suggested fix:** Add a short current-state note for the flat row picker pattern and mark old card-heavy guidance as historical where it no longer applies.

## Priority Summary

Fix these first:

1. **Make persistence and side effects transactional** for task save/delete, board delete, import failure, and reset reseed failure. This is the biggest data-integrity risk.
2. **Stop mutating SwiftData during speculative drag hover** or add reliable rollback for every reorder surface. This is the biggest interaction-state risk.
3. **Clarify and harden reminder scheduling**, especially finite repeat batches and ignored notification scheduling errors.
4. **Fix widget selection semantics** for active working ranges and align widget copy with actual data.
5. **Expand tests around persistence, import/export, widget snapshots, reminders, and drag reorder** so the high-risk flows are covered before more UI redesign work.
