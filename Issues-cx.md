# Issues-cx Review

Review target: current working tree in `/Users/ijustin/Library/CloudStorage/GoogleDrive-ijustinzhong@gmail.com/My Drive/Code/Task`.

Validation run during review:

- `rtk xcodebuild -project task.xcodeproj -list` succeeded and found `Task`, `TaskWidgetExtension`, and `TaskTests`.
- `rtk xcodebuild -project task.xcodeproj -scheme Task -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/task-project-issue-review-derived-data build-for-testing CODE_SIGNING_ALLOWED=NO` succeeded.
- `rtk xcodebuild -project task.xcodeproj -scheme Task -destination 'platform=iOS Simulator,id=C8D34B81-AD9F-4B30-A710-2F3C7E1BEFD6' -derivedDataPath /private/tmp/task-project-issue-review-derived-data test-without-building CODE_SIGNING_ALLOWED=NO` succeeded.

This repository is a SwiftUI/SwiftData iOS task manager with a WidgetKit extension. It is not a data-science or ML project, so data loading/preprocessing, feature engineering, model training, model evaluation, and prediction concerns are not applicable beyond the app's import/export data path.

Resolution update — 2026-05-26:

- Addressed in build 8: checkbox completion clears reminders, task save failure rollback, board delete side-effect ordering, imported reminder-time validation, date formatter locale cache reset, widget board/status list refreshes, IME-safe notes restyling, confirmation-sheet revert per product direction, README command-line verification docs, and related regression tests.
- Addressed in build 7 just before this pass: stale repeating reminder auto-advance on app activation, card/status display limits, date picker clearing, notes indentation/card previews, localization cleanup, and release documentation alignment.
- Deferred intentionally: date-only storage/export migration, broad import/search/widget performance rewrites, app-wide SwiftData save abstraction, ML/data-science items that do not apply to this app, and signing-team policy changes.

## Critical Bugs

### Completed checkbox tasks can still fire reminders

- **Severity:** High
- **Location:** `Task/Views/Board/ColumnView.swift`, `toggleTaskChecked(_:)`; `Task/Views/Task/TaskDetailView.swift`, `save()`; `Task/Services/NotificationService.swift`, `schedule(for:)`; `Task/Services/UpcomingSnapshotBuilder.swift`, `writeSnapshot(from:)`
- **Problem:** Checking a task off only toggles `isChecked`, saves, and refreshes the widget snapshot. It does not cancel an existing pending reminder. The widget intentionally hides checked checkbox tasks, but `NotificationService.schedule(for:)` and `TaskDetailView.save()` do not treat `showsCheckbox && isChecked` as a completed state.
- **Why it matters:** A user can mark a task done, see it disappear from the widget, and still receive the old local notification later. That creates a direct mismatch between visible completion state and reminder behavior.
- **Suggested fix:** Decide whether checked tasks should be considered complete for reminders. If yes, cancel pending notifications when a task becomes checked, skip scheduling while checked, and reschedule only if the user unchecks a future reminder task. Add tests for check, uncheck, and save-from-editor flows.

### Existing task edits are not rolled back when save fails

- **Severity:** High
- **Location:** `Task/Views/Task/TaskDetailView.swift`, `save()`
- **Problem:** The edit path mutates the existing `TaskItem` before `try context.save()`. If the save throws, the catch block deletes only new tasks, dismisses, and returns. It does not call `context.rollback()` for edited tasks.
- **Why it matters:** The UI reports the edit as abandoned because notification/widget side effects are skipped and the sheet closes, but the dirty in-memory model remains in the `ModelContext`. A later unrelated save can persist the failed edit.
- **Suggested fix:** In the save catch block, call `context.rollback()` for existing edits. Keep the sheet open or show an error instead of dismissing. Add a failing-save test that verifies edited fields do not persist through a subsequent successful save.

### Board deletion cancels reminders before persistence succeeds

- **Severity:** High
- **Location:** `Task/Views/Board/BoardSwitcherView.swift`, `deleteBoard(_:)`
- **Problem:** Board deletion cancels every task notification before `context.delete(board)` and `try? context.save()`. The save error is ignored, then the widget snapshot is written and the active board may be switched.
- **Why it matters:** If the delete save fails, the board and tasks can remain in SwiftData with their reminders already cancelled. The widget and active-board state can also move forward as if deletion succeeded.
- **Suggested fix:** Save the deletion first, then cancel notifications and write snapshots only after a successful save. On failure, rollback and surface an alert. This should mirror the safer delete pattern already used in `TaskDetailView.delete()`.

### Repeating reminders stop unless the app becomes active again

- **Severity:** High
- **Location:** `Task/Services/NotificationService.swift`, `fireDates(for:now:calendar:)`; `Task/Views/RootView.swift`, `refreshRepeatReminders()`
- **Problem:** A repeating reminder schedules only the current resolved fire date. After that notification fires, the next occurrence is created only when the app later becomes active and `refreshRepeatReminders()` advances the stored dates.
- **Why it matters:** The UI exposes daily, weekly, biweekly, monthly, quarterly, and annual repeat rules. Users will reasonably expect ongoing notifications even if they do not open the app between occurrences.
- **Suggested fix:** Either make the limitation explicit in the UI, or maintain a rolling notification window for repeating tasks. For example, schedule the maximum safe future occurrences across active repeating reminders and refresh that queue whenever a notification is delivered, edited, or the app becomes active.

## Data Processing Issues

### Date-only fields are stored and exported as absolute instants

- **Severity:** Medium
- **Location:** `Task/Models/TaskItem.swift`, `workingStart`, `workingEnd`, `dueDate`; `Task/Services/DataImportExport.swift`, `makeEncoder()` and `makeDecoder()`
- **Problem:** Working dates and due dates are date-only concepts in the UI, but the model stores them as `Date` and the export path encodes them with ISO8601 instants.
- **Why it matters:** Midnight-local dates can shift calendar days across time zones, device locale changes, or imports generated outside the app. A backup made in one time zone can restore to a different visible day elsewhere.
- **Suggested fix:** Store/export date-only values as `yyyy-MM-dd` strings or explicit `DateComponents`. Convert to local `Date` only at UI and notification boundaries. Add round-trip tests across at least two time zones.

### Imported reminder time is not range validated

- **Severity:** Medium
- **Location:** `Task/Services/DataImportExport.swift`, `mergeBoard(_:,into:plan:)`; `Task/Services/NotificationService.swift`, `resolvedFireDate(for:calendar:)`; `Task/Views/Settings/SettingsView.swift`, `reminderTimeLabel`
- **Problem:** Import assigns `BoardExport.reminderMinutesOfDay` directly when present. The UI picker validates 0..<1440, but hand-edited or malformed JSON can import invalid values such as -1 or 2000.
- **Why it matters:** Invalid reminder minutes flow into notification date components and settings formatting. This can schedule at the wrong time, fail to schedule, or render nonsensical reminder labels.
- **Suggested fix:** Clamp or reject imported reminder times outside 0..<1440. Count invalid board preferences as import warnings and keep the existing/default board value when the payload is invalid.

### Export schema documentation is inconsistent with current import behavior

- **Severity:** Low
- **Location:** `README.md`, `Data Format`; `LessonsLearned.md`, `Data import / export`
- **Problem:** The README points readers to `LessonsLearned.md` for the full schema. The import/export notes in that file still include older behavior such as "six default groups" and single-board reuse, while the newer multi-board notes later in the same file say board matching is ID-only.
- **Why it matters:** Import/export is the user's only backup path. Stale schema guidance makes external test data and manual backup repair more error-prone.
- **Suggested fix:** Move the current v2 JSON schema into a dedicated docs page or README subsection, and trim old behavior in `LessonsLearned.md` to clearly marked historical notes.

## Model / Data Science Issues

### No model-training or prediction pipeline is present

- **Severity:** Low
- **Location:** Project-wide
- **Problem:** The requested review scope includes model training, feature engineering, prediction, and evaluation code, but this repository does not contain an ML or data-science pipeline.
- **Why it matters:** There are no model reproducibility, train/test leakage, feature-engineering, or evaluation concerns to audit.
- **Suggested fix:** No app change is needed. If ML features are added later, introduce explicit modules for consent, feature extraction, model versioning, evaluation, and deterministic tests.

## UI / Dashboard Issues

### Live Markdown editing can break marked text input

- **Severity:** High
- **Location:** `Task/Views/Task/MarkdownNotesEditor.swift`, `LiveMarkdownTextView.Coordinator.textViewDidChange(_:)` and `apply(_:to:)`
- **Problem:** Every text change rewrites `textView.attributedText` and restores `selectedRange`. The code does not check `markedTextRange` before replacing the attributed text.
- **Why it matters:** Chinese/Japanese/Korean keyboards and other IME flows use marked text while the user is composing characters. Replacing the attributed text during composition can drop candidates, move the cursor, or commit partial text incorrectly. The app ships Simplified Chinese localization, so this is a realistic input path.
- **Suggested fix:** Skip live restyling while `textView.markedTextRange != nil`, or style only after composition commits. Add a focused UI test/manual test plan for Simplified Chinese Pinyin input in the notes editor.

### Date formatter cache keeps old locale-specific patterns after language changes

- **Severity:** Medium
- **Location:** `Task/Utils/DateFormatters.swift`, `TaskDateFormat.locale` and `formatter(for:)`; `Task/ViewModels/SettingsViewModel.swift`, language `didSet`
- **Problem:** Cached `DateFormatter`s are created with `setLocalizedDateFormatFromTemplate`, but when the app language changes the cache only updates each formatter's `locale`. It does not regenerate the localized date format pattern.
- **Why it matters:** Month names may switch language, but ordering and punctuation can stay in the old locale's pattern. For example, an English-created `MMMd` formatter changed to `zh-Hans` can render `12月 31` instead of the Chinese pattern `12月31日`.
- **Suggested fix:** Clear `styledFormatters` when `locale` changes, or rebuild each cached formatter by calling `setLocalizedDateFormatFromTemplate` again for the new locale. Add a test that formats the same date before and after switching to `zh-Hans`.

### Widget board/status configuration lists can go stale after reorder or status add

- **Severity:** Medium
- **Location:** `Task/Services/UpcomingSnapshotBuilder.swift`, `writeSnapshot(from:)`; `Task/Views/Board/BoardSwitcherView.swift`, reorder `onCommit`; `Task/Views/Task/StatusPickerSheet.swift`, reorder `onCommit` and `addGroup()`
- **Problem:** The App Group board/status lists are written only inside `UpcomingSnapshotBuilder.writeSnapshot(from:)`. Board reordering, status reordering, and status creation save SwiftData but do not refresh the shared lists.
- **Why it matters:** The widget edit sheet reads those lists from shared defaults. Newly added statuses or reordered boards/statuses can remain missing or out of order until an unrelated action happens to rewrite the snapshot.
- **Suggested fix:** Refresh the shared board/status list after every board/status create, rename, delete, and reorder. Consider extracting a narrower shared-list writer so these updates do not require a full upcoming-task snapshot and timeline reload.

### Confirmation sheets use a fixed 360 point detent

- **Severity:** Medium
- **Location:** `Task/Components/ConfirmationSheet.swift`, `confirmationSheetPresentationStyle()`
- **Problem:** Confirmation sheets use `.presentationDetents([.height(360)])` while their content uses dynamic type, localized strings, and user-supplied names in messages.
- **Why it matters:** Destructive confirmations must stay readable and tappable. Larger text settings or longer localized board/status/tag names can clip the message or actions.
- **Suggested fix:** Use adaptive detents, add a scroll container inside the sheet, or provide a larger fallback detent for accessibility and longer localized text.

## Code Quality Issues

### Many SwiftData writes still swallow save failures

- **Severity:** Medium
- **Location:** Examples include `Task/Views/Board/ProjectHeaderView.swift`, `GroupMenuSheet.swift`, `BoardSwitcherView.swift`, `ColumnView.swift`; `Task/Views/Task/StatusPickerSheet.swift`, `TagPickerSheet.swift`; `Task/Views/Settings/AppearanceView.swift`, `CardOrderPickerSheet.swift`; `Task/Services/SwiftDataManager.swift`
- **Problem:** User-visible write paths frequently use `try? context.save()` and then continue as if persistence succeeded. Some of these paths also write widget snapshots or schedule/cancel notifications after ignored failures.
- **Why it matters:** SwiftData is the source of truth for the app. Silent save failure can create data loss, stale widgets, wrong reminders, and dirty in-memory state that persists on a later unrelated save.
- **Suggested fix:** Add a small persistence helper that returns a result and centralizes logging/user alerts. Use explicit `do/catch` plus rollback for destructive writes and for any write followed by widget or notification side effects.

### Notification scheduling ignores `UNUserNotificationCenter.add` failures

- **Severity:** Medium
- **Location:** `Task/Services/NotificationService.swift`, `schedule(for:)`
- **Problem:** `UNUserNotificationCenter.current().add(_:withCompletionHandler:)` is called with a nil completion handler.
- **Why it matters:** The task can show `hasReminder == true` even if iOS rejects the request due to invalid trigger data, authorization state, notification limits, or another system error.
- **Suggested fix:** Use the completion handler or async notification APIs. Return a schedule result and surface failures in the editor when a reminder could not actually be queued.

### App Group snapshot read/write failures are silent

- **Severity:** Low
- **Location:** `Task/Services/SharedDefaultsService.swift`; `TaskWidgetExtension/WidgetSnapshot.swift`
- **Problem:** Shared defaults reads and writes quietly return or fall back to empty data when the App Group suite is unavailable or JSON encoding/decoding fails.
- **Why it matters:** Widget configuration and upcoming tasks can disappear without any development-time signal. This makes entitlement, schema drift, and corrupt snapshot bugs harder to diagnose.
- **Suggested fix:** Log App Group read/write/codec failures with `Logger`, include snapshot schema/version fields, and add a debug-only assertion or diagnostics row for missing shared defaults.

## Performance Issues

### Import and storage operations do heavy work on the main actor

- **Severity:** Medium
- **Location:** `Task/Views/Settings/SettingsView.swift`, `handleImportResult(_:)`, `performExport()`, and `checkStorage()`; `Task/Services/DataImportExport.swift`, `importData(_:context:)` and `storageSummary(context:)`
- **Problem:** Import reads the selected file with `Data(contentsOf:)` on the main thread, then decodes and merges on the main actor. Storage check exports the full dataset to count bytes.
- **Why it matters:** Large backups or large local datasets can freeze the settings UI even though a progress overlay is visible. The overlay appears after the synchronous file read.
- **Suggested fix:** Read and decode the file off the main actor, validate the payload before entering the main actor, and batch main-actor SwiftData mutations. Cache or estimate storage size instead of fully exporting on every storage check.

### Search scans every task on every keystroke

- **Severity:** Medium
- **Location:** `Task/Views/Search/SearchView.swift`, `groupedResults`
- **Problem:** Each render lowercases the query, scans all tasks in every board, lowercases title/notes/group/tag fields, and sorts matches on the main thread.
- **Why it matters:** This will become typing lag as task count grows, especially because search updates continuously while the text field is focused.
- **Suggested fix:** Debounce query updates, cache normalized searchable text per task, and move search work into a view model. For larger datasets, consider SwiftData predicates for the first-pass title/notes search.

### Widget snapshots fetch all tasks and reload all timelines after many saves

- **Severity:** Low
- **Location:** `Task/Services/UpcomingSnapshotBuilder.swift`, `writeSnapshot(from:)`
- **Problem:** Snapshot writing fetches every task and board, encodes JSON, writes shared defaults, writes board/status lists, and calls `WidgetCenter.shared.reloadAllTimelines()`.
- **Why it matters:** Frequent edits can cause avoidable main-thread work and widget reload churn, including for changes that cannot affect upcoming widget content.
- **Suggested fix:** Debounce snapshot writes, narrow the task fetch to date-bearing tasks in the widget window when possible, and split board/status list updates from upcoming-task timeline reloads.

## Missing Tests

### Persistence failure and side-effect ordering are not covered

- **Severity:** High
- **Location:** `TaskTests/TaskTests.swift`; affected implementation in `TaskDetailView`, `BoardSwitcherView`, picker sheets, and `NotificationService`
- **Problem:** The test suite covers many pure helpers and release/localization checks, but it does not exercise save-failure recovery, rollback behavior, notification cancellation ordering, or widget snapshot writes after failed saves.
- **Why it matters:** The riskiest bugs in this app are cross-boundary bugs where SwiftData, notifications, and widget state diverge. Pure helper tests will not catch those regressions.
- **Suggested fix:** Inject notification and widget-writer protocols, add a save-failing persistence seam for tests, and assert that side effects occur only after durable saves.

### Input method and accessibility layout coverage is missing

- **Severity:** Medium
- **Location:** `Task/Views/Task/MarkdownNotesEditor.swift`; `Task/Components/ConfirmationSheet.swift`; UI test target/project configuration
- **Problem:** There are unit tests for markdown parsing/styling, but no simulator/UI coverage for IME composition, dynamic type clipping, or long localized destructive confirmation text.
- **Why it matters:** The app supports Simplified Chinese and an in-app text-size setting. Bugs in these areas are visible to users but hard to catch with pure unit tests.
- **Suggested fix:** Add a small UI test plan or manual release checklist for Pinyin input in notes, largest text-size confirmation sheets, and long board/status/tag names.

### Widget configuration freshness is not tested end to end

- **Severity:** Medium
- **Location:** `Task/Services/UpcomingSnapshotBuilder.swift`; `TaskWidgetExtension/*`; `TaskTests/TaskTests.swift`
- **Problem:** Tests cover status-list ordering as a pure helper, but not whether every board/status mutation writes the shared App Group data that the widget configuration queries read.
- **Why it matters:** The app and widget duplicate Codable structs and communicate through shared defaults. It is easy for a new mutation path to update SwiftData without refreshing widget configuration data.
- **Suggested fix:** Add tests around board reorder, status add, status reorder, status rename, and board delete that assert the shared board/status list is refreshed.

## Configuration / Dependency Issues

### Command-line build and test invocation is not documented

- **Severity:** Low
- **Location:** `README.md`, `Build`
- **Problem:** The README only tells contributors to open `task.xcodeproj` in Xcode. It does not document the `xcodebuild` command, simulator destination, or derived-data setup used for automated verification.
- **Why it matters:** Reproducible review and release checks depend on local knowledge. Contributors can build manually but may skip the test suite.
- **Suggested fix:** Add a command-line build/test section with the intended scheme and simulator destination, plus a note that CI should run the same command.

### Default signing team is committed in tracked config

- **Severity:** Low
- **Location:** `Config/Signing.xcconfig`
- **Problem:** The tracked config includes a concrete `DEVELOPMENT_TEAM` value.
- **Why it matters:** This is not a secret, but it makes contributor builds target the maintainer's team by default and can be surprising in a public/source-available repo.
- **Suggested fix:** Leave the tracked `DEVELOPMENT_TEAM` empty and rely on `Config/Signing.local.xcconfig`, or document that the committed value is intentional for maintainer builds.

## Summary

Top priorities:

1. Fix reminder/data divergence first: checked tasks should not keep firing reminders, failed task edits need rollback, and board deletion must cancel notifications only after save success.
2. Decide how repeating reminders should behave when the app is not opened between occurrences.
3. Harden localized input and date formatting, especially the notes IME path and cached locale-specific date patterns.
4. Replace broad `try? context.save()` write paths with explicit save results before adding more features.
5. Add tests that exercise persistence failure, notification/widget side effects, and widget configuration freshness.
