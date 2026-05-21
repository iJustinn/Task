# Task — Issues Report

Audit of branch `task-v0.2.0` on 2026-05-19. Read-only review; no code was
modified.

Severity legend: Critical (data loss / crash / store-blocking), High
(incorrect behavior or significant UX regression under normal use), Medium
(bug or hygiene risk under specific conditions), Low (quality, performance,
or maintainability delta).

---

## 1. Project review summary

Task v0.1.0 (build 1) ships a coherent single-board Kanban app with
SwiftData persistence, a home-screen widget, local notifications, and a
polished iOS 18/26 UI. Architecture and Swift model decisions are sound and
align with LessonsLearned. The biggest risks today are widget-staleness
(timelines are never reloaded after data changes), drag-reorder behavior
when the user is in a non-manual sort mode (silently rewrites manual
sortIndex), and a few snapshot/refresh paths that drift away from the
displayed board after group edits. Import is non-destructive but quietly
drops references to unknown groups/tags. UI is consistent overall, with a
handful of inconsistencies in sheet toolbars and one cosmetic icon
placement on cards. Areas reviewed: models, services, view models, all
views (board, task detail, search, settings, customization, about),
components, widget target, project configuration, entitlements, privacy
info, and Localizable.xcstrings spot-checks. Not reviewed: live runtime
behavior, on-device notification delivery, instrument/performance traces,
asset catalog contents.

---

## 2. Issue list

### N1. Widget timeline is never reloaded after data changes

- **Severity:** High
- **Related files:** `Task/Views/Task/TaskDetailView.swift:454-471`,
  `Task/Views/Board/BoardView.swift:42-47`,
  `Task/Services/DataImportExport.swift:248,263`,
  `Task/Views/RootView.swift:57-60`
- **Description:** `UpcomingSnapshotBuilder.writeSnapshot(from:)` is the
  only mechanism the main app uses to push state to the widget, and it is
  called after task save/delete, cross-column drops, import, reset, and
  on app launch. However, `WidgetCenter.shared.reloadAllTimelines()` is
  never called anywhere in `Task/`: `grep -rn "WidgetCenter\|reloadAllTimelines" Task/`
  returns no matches. Because `UpcomingTasksProvider.getTimeline`
  schedules the next refresh `.after(now + 1 hour)`, the home-screen
  widget can stay up to ~60 minutes behind the JSON snapshot the app just
  wrote. LessonsLearned explicitly calls this out as a requirement.
- **Why it matters:** Visible regression — users edit a task in the app,
  switch to the home screen, and see stale data on the Upcoming Tasks
  widget. Especially confusing right after creating a task with a
  reminder.
- **Suggested fix:** Add `import WidgetKit` and call
  `WidgetCenter.shared.reloadAllTimelines()` immediately after each
  `SharedDefaultsService.writeUpcoming(...)` (i.e. inside
  `UpcomingSnapshotBuilder.writeSnapshot`). Calling it from inside the
  builder is one line and centralizes the contract.
- **Risks / dependencies:** None. `reloadAllTimelines()` is a no-op when
  the widget is not installed. Safe on the main thread.

### N2. Drag-reorder silently corrupts manual order when in a non-manual sort

- **Severity:** High
- **Related files:** `Task/Views/Board/ColumnView.swift:51-66,113-129`,
  `Task/Views/Board/BoardView.swift:49-57`,
  `Task/Models/BoardGroup.swift:28-71`
- **Description:** The visible task list inside a column is
  `currentTasks = group.sortedTasks(field: settings.cardSortField, direction: settings.cardSortDirection)`,
  which honors title or date sort. The drop index passed to
  `handleDrop(raw:fallbackIndex:)` comes from this sorted view. But
  `BoardView.reorder(_:in:toIndex:)` (line 49) uses
  `group.orderedTasks` (`tasks.sorted { $0.sortIndex < $1.sortIndex }`)
  and then assigns `t.sortIndex = i` for each task. The two orderings can
  differ. The user dropping at visual position 5 in a title-sorted column
  produces a sortIndex assignment unrelated to their intent, silently
  rewriting their manual order.
- **Why it matters:** Two failure modes. In title/date mode, the user
  thinks "I'm rearranging cards" but the column doesn't visibly change,
  giving the impression that drag does nothing. Later, switching to
  Manual sort reveals a scrambled, history-dependent order. This is
  particularly damaging because Manual order is the user's curated
  arrangement.
- **Suggested fix:** Either (a) disable card drag-reorder when
  `settings.cardSortField != .manual` (drag would still work for
  cross-column moves but not for within-column reorder), or (b) compute
  `fallbackIndex` against `group.orderedTasks` (sortIndex order) so the
  reorder math is internally consistent regardless of display sort. (a)
  is the surgical, user-clear option.
- **Risks / dependencies:** If choosing (a), check that cross-column
  drops still work (`onDropTask` must run before the reorder is
  short-circuited). The simplest implementation is to short-circuit
  `onReorder` for same-group drops only when `cardSortField != .manual`,
  and still run `onReorder` after cross-column moves but at end-of-list.

### N3. Group rename / recolor / delete does not refresh the upcoming snapshot

- **Severity:** High
- **Related files:** `Task/Views/Board/GroupMenuSheet.swift:94-115`,
  `Task/Services/SharedDefaultsService.swift:11-19`,
  `Task/Services/UpcomingSnapshotBuilder.swift:18-27`
- **Description:** The upcoming snapshot embeds `groupName` and
  `groupColorKey` for each entry (see `UpcomingSnapshotEntry`).
  `GroupMenuSheet.save` writes name/color changes and
  `deleteAndDismiss` reassigns the deleted group's tasks to a fallback
  group, but neither calls `UpcomingSnapshotBuilder.writeSnapshot(from:)`
  after `try? context.save()`. The widget therefore shows the old group
  name/color (and, after a group is deleted, the old group name) until
  another snapshot-writing action runs (task save/delete/import/reset
  or app re-launch).
- **Why it matters:** Visible widget staleness following common
  customization gestures. Compounded by N1, the gap can be hours.
- **Suggested fix:** Append
  `UpcomingSnapshotBuilder.writeSnapshot(from: context)` to both `save()`
  (line 94) and `deleteAndDismiss()` (line 101) after the save.
- **Risks / dependencies:** None. `writeSnapshot` is a single fetch+
  encode and is safe on `@MainActor`.

### N4. Card reminder icon attaches to the wrong date row

- **Severity:** Medium
- **Related files:** `Task/Views/Board/TaskCardView.swift:29-44`,
  `Task/Components/DateRow.swift:1-23`,
  `Task/Models/TaskItem.swift:45-47`
- **Description:** `TaskItem.primaryReminderDate` resolves to
  `dueDate ?? workingEnd ?? workingStart`, so the reminder actually
  fires on the due date when one is set. But the card only forwards
  `hasReminder` to the working `DateRow` (line 35), while `DueDateRow`
  takes no `hasReminder` argument. Concretely:
  - Task with only a working date + reminder → alarm shows on working
    row → correct.
  - Task with only a due date + reminder → no alarm icon on the card →
    user has no indication a reminder will fire.
  - Task with both + reminder → alarm shows on working row, but the
    reminder fires on the due date → icon is on the wrong row.
- **Why it matters:** Users glance at cards to verify their reminders
  are set; the icon's placement is the signal. Misplaced or absent icons
  undermine that.
- **Suggested fix:** Move the alarm to the row that corresponds to
  `primaryReminderDate`. Simplest implementation: pass `hasReminder &&
  task.dueDate != nil` to `DueDateRow` (give it an alarm icon path), and
  `hasReminder && task.dueDate == nil` to the working `DateRow`. Update
  `DueDateRow` to accept and render the alarm.
- **Risks / dependencies:** None. Layout impact is one additional
  optional SF Symbol per row.

### N5. Import silently drops task references to unknown groups and tags

- **Severity:** Medium
- **Related files:** `Task/Services/DataImportExport.swift:210-245`
- **Description:** When merging tasks, the resolver writes
  `existing.group = groupsByID[gid]` and
  `existing.tags = t.tagIDs.compactMap { tagsByID[$0] }`. If the imported
  task's `groupID` doesn't match any merged group (and didn't pre-exist),
  the task becomes orphaned with `group = nil`, which makes it invisible
  on the board (the board iterates `board.orderedGroups`, never standalone
  tasks). `compactMap` similarly drops any tagIDs that don't resolve, with
  no warning to the user.
- **Why it matters:** A user re-importing a partial export, or an export
  authored externally with mismatched references, would silently lose
  task visibility and tag membership. The Reset All Data flow makes this
  worse: after reset, the seeded groups have brand-new UUIDs, and only
  the name-match fallback for groups/tags saves the import — there is no
  such fallback for tasks → groupID linkage.
- **Suggested fix:** After resolving, if `t.groupID != nil` but
  `groupsByID[gid] == nil`, fall back to `groupsByID[anyExisting] ??
  board.orderedGroups.first` so tasks land somewhere visible (and log).
  Tags can stay best-effort but consider surfacing the dropped-count in
  the success alert ("Imported N tasks. M references couldn't be
  resolved.").
- **Risks / dependencies:** None for the group fallback. The user-facing
  count requires plumbing a result struct through `importData`.

### N6. `.swipeActions` on ManageTagsView rows is a no-op

- **Severity:** Medium
- **Related files:** `Task/Views/Settings/ManageTagsView.swift:78-124,140-143`
- **Description:** `tagRow(_:)` attaches `.swipeActions(edge:
  .trailing, ...) { Button(role: .destructive) { pendingDelete = tag }
  ... }` but the row is rendered inside a custom `VStack(spacing: 0)`
  inside `SettingsCardSection`, not a SwiftUI `List`.
  `.swipeActions` only attaches to `List` rows; on a generic `HStack`
  inside a `VStack` the modifier is silently ignored, so the swipe
  gesture never reaches the delete button. The only delete path that
  works is from inside `TagEditSheet`. The companion `private func
  delete(_ tag:)` at line 140 has no callers.
- **Why it matters:** Discoverability — swipe-to-delete on list-like rows
  is a strong iOS convention; users will try it and get no response.
- **Suggested fix:** Either rebuild `tagsSection` on top of `List` (with
  `.listStyle(.plain)` and matching row backgrounds) so the swipe works,
  or replace the swipe with a visible inline destructive button. If
  rebuilding on `List`, also drop the unused `delete(_ tag:)` helper.
- **Risks / dependencies:** `List` rendering will require restyling to
  match the card visual. The simpler patch is to surface a trash icon
  in the trailing area of each row.

### N7. Persistent-store failure silently falls back to an in-memory store

- **Severity:** Medium
- **Related files:** `Task/Services/SwiftDataManager.swift:12-25`
- **Description:** `makeModelContainer()` catches any error from opening
  the persistent store and returns an in-memory `ModelContainer` via
  `try!`. The user is given no signal that their data is now ephemeral.
  Worse, the next launch will attempt the persistent store again, and
  if it succeeds the in-memory writes (created today) are lost.
- **Why it matters:** Silent data loss on schema/migration failure.
  Catches a real production case if a future model change is
  non-additive.
- **Suggested fix:** Log + surface a banner. At minimum, persist a flag
  `SharedDefaultsService.lastLaunchWasInMemory = true` and have
  `RootView` show a one-time alert ("Storage error — please export your
  data") when the flag is set. Optionally rename/move the corrupt store
  file so subsequent launches can recover.
- **Risks / dependencies:** Recovery semantics need product input. The
  current `try!` of the in-memory fallback will still crash the app if
  even the in-memory store can't be created (extreme edge case).

### N8. Notifications scheduled for past dates fail silently

- **Severity:** Medium
- **Related files:** `Task/Services/NotificationService.swift:12-32`
- **Description:** `schedule(for:)` does not check whether the computed
  `fireDate` (date components → `UNCalendarNotificationTrigger`) is in
  the past. `UNCalendarNotificationTrigger(dateMatching:repeats:)` with a
  past date simply never fires; the user gets no warning. Easy to
  reproduce: enable reminder on a task whose due date is yesterday or
  earlier today (before 9 AM if no time set).
- **Why it matters:** User believes a reminder is set, no reminder
  arrives.
- **Suggested fix:** Before scheduling, compute the resolved fire date
  from `components` and bail out if it's `< Date()`. Optionally surface a
  subtle warning in `TaskDetailView` ("Reminder date is in the past —
  no notification will fire") when the user toggles reminder on for a
  past date.
- **Risks / dependencies:** None.

### N9. Large imports and resets block the main thread under the progress overlay

- **Severity:** Medium
- **Related files:** `Task/Services/DataImportExport.swift:111-249,253-264`,
  `Task/Views/Settings/SettingsView.swift:436-455`
- **Description:** Both `importData(_:context:)` and `resetAll(context:)`
  are annotated `@MainActor`, perform multiple `context.fetch(...)`
  passes, mutate models in tight loops, and call `try? context.save()`.
  `SettingsView.handleImportResult` schedules them on the main actor
  while displaying a `ProgressOverlay`, but the overlay itself can't
  redraw if the actor is busy. On a board with thousands of tasks/tags
  this can freeze the UI for seconds.
- **Why it matters:** Apparent app hang on large datasets. Not relevant
  for typical hobbyist data; could be felt for power users or pre-seeded
  imports.
- **Suggested fix:** Move the heavy work onto a background `ModelContext`
  and merge to the main context, or chunk the loops with `await
  Task.yield()` so the overlay can repaint. Adding actual progress
  (`progress:` argument on `ProgressOverlay`) becomes feasible at that
  point.
- **Risks / dependencies:** Multi-context coordination has its own
  pitfalls (object identities across contexts). Start by yielding inside
  the existing main-actor loop as the smaller change.

### N10. `iCloud Sync (Coming Soon)` row is non-interactive but rendered as a content row

- **Severity:** Low
- **Related files:** `Task/Views/Settings/SettingsView.swift:254-274`
- **Description:** The iCloud Sync row in the Data section is a
  `SettingsRowLabel` (not a button), with `value: "Coming Soon"` and no
  accessory. It looks visually like the surrounding interactive rows
  (same icon tile, same row height), which can lead users to tap it
  hoping for at least a brief explanation.
- **Why it matters:** Minor UX confusion.
- **Suggested fix:** Either dim the row (`foregroundColor(.secondary)`
  on the title) or convert it to a tappable button that opens a small
  sheet explaining the roadmap. Keep it consistent with how other
  "Coming Soon" affordances will eventually behave.
- **Risks / dependencies:** None.

### N11. Settings sheet toolbars are inconsistent

- **Severity:** Low
- **Related files:** `Task/Views/Settings/SettingsView.swift:67-71`,
  `Task/Views/Settings/AboutSheets.swift:233-238`,
  `Task/Views/Settings/ManualControlSheet.swift:53-56`,
  most picker sheets in `Task/Views/Settings/*.swift`
- **Description:** Per LessonsLearned, picker sheets standardize on
  `Cancel` (top-leading) + `Done` (top-trailing). Settings has only
  `Done` top-trailing; Feedback has only `Cancel` top-leading; Manual
  Control has only `Done` top-leading. Each is defensible in isolation
  but the lack of a shared rule across the app is jarring when users
  navigate from one to the next.
- **Why it matters:** Polish item; reflects on perceived quality.
- **Suggested fix:** Codify the rule: every modal sheet uses
  `Cancel` (top-leading) + `Done` (top-trailing). For "info only"
  sheets that have no Save action, both buttons can call `dismiss()`;
  this matches the existing picker sheets.
- **Risks / dependencies:** None.

### N12. README documents a `Task/Info.plist` that does not exist

- **Severity:** Low
- **Related files:** `README.md:83`, `task.xcodeproj/project.pbxproj:453-459`,
  `task.xcodeproj/project.pbxproj:524-525`
- **Description:** The README's Project Structure listing includes
  `Task/Info.plist`. The Task target uses `GENERATE_INFOPLIST_FILE = YES`
  with explicit `INFOPLIST_KEY_*` settings — there is no checked-in
  `Task/Info.plist`. Only the widget extension has a real
  `TaskWidgetExtension/Info.plist`.
- **Why it matters:** Onboarding confusion when contributors look for
  the missing file and assume something is wrong.
- **Suggested fix:** Remove the `Task/Info.plist` line from the README
  project tree, or add a parenthetical "(generated)" next to it.
- **Risks / dependencies:** None.

### N13. `BoardView.moveTask` and `BoardView.reorder` save the context twice on a cross-column drop

- **Severity:** Low
- **Related files:** `Task/Views/Board/BoardView.swift:42-57`,
  `Task/Views/Board/ColumnView.swift:113-129`
- **Description:** A cross-column drop triggers `onDropTask` (calls
  `moveTask` → `try? context.save()` + `writeSnapshot`) and then
  `onReorder` (calls `reorder` → `try? context.save()`). Two saves for
  one user action, with a snapshot write sandwiched in the middle (and
  no widget reload either).
- **Why it matters:** Negligible runtime cost; more an inconsistency
  hint that the cross-column path could become a single transactional
  call.
- **Suggested fix:** Collapse into a single `moveAndReorder(task:to:at:)`
  on `BoardView` that updates `task.group`, recomputes sortIndex, saves
  once, writes the snapshot, and reloads timelines (see N1).
- **Risks / dependencies:** Touching the drag handler — keep
  cross-column and within-column code paths distinct in the new
  function.

### N14. `Bundle.main.object(forInfoDictionaryKey:)` repeats in two places

- **Severity:** Low
- **Related files:** `Task/Views/Settings/SettingsView.swift:457-461`,
  `Task/Views/Settings/AboutSheets.swift:259-262`
- **Description:** Both `SettingsView.appVersion` and
  `FeedbackSheet.feedbackBody` read the version + build from
  `Bundle.main.infoDictionary`. The strings differ slightly ("Unknown"
  vs default "0.0"/"1"), which can confuse if one path renders during
  an edge case where the keys are missing.
- **Why it matters:** Maintenance and consistency.
- **Suggested fix:** Extract `Bundle.main.shortVersionString` /
  `bundleVersion` helpers, used by both sites with the same fallback.
- **Risks / dependencies:** None.

### N15. Snapshot encoding uses default JSON Date strategy; export uses ISO 8601

- **Severity:** Low
- **Related files:** `Task/Services/SharedDefaultsService.swift:26-37`,
  `Task/Services/DataImportExport.swift:53-64`
- **Description:** `writeUpcoming(_:)` uses
  `JSONEncoder()` with default Date strategy (timeIntervalSinceReferenceDate
  as Double). `DataImportExport.makeEncoder()` uses ISO 8601. The
  widget reads with default `JSONDecoder()` so the snapshot pipe is
  internally consistent, but having two different conventions for
  "our JSON" makes it easy to introduce a mismatch in a future change.
- **Why it matters:** Future-proofing more than a current bug.
- **Suggested fix:** Standardize both paths on
  `dateEncodingStrategy = .iso8601`. The widget decoder must match
  — set `.iso8601` on `WidgetSharedDefaults.read()` too.
- **Risks / dependencies:** Existing snapshots in the App Group
  container would decode as `nil` for date fields until the next
  snapshot is written, which `RootView.task` triggers on launch. Low
  blast radius.

---

## 3. Code quality findings

- **Duplicated code:**
  - Version/build string lookup repeated in `SettingsView.swift:457-461`
    and `AboutSheets.swift:259-262`.
  - `Bundle.main.object(forInfoDictionaryKey:)` calls split across two
    files with different fallbacks (see N14).
  - "Empty" placeholder rendering repeated 4× in
    `TaskDetailView.swift:196,217,253,278` — could be a tiny private
    helper.
  - Chevron-only "trailing" view repeated in
    `SettingsView.swift:269-272,283-287,295-298,307-310,317-320,328-331`.
  - App color palette is duplicated between `Task/Models/ColorKey.swift`
    and `TaskWidgetExtension/WidgetSnapshot.swift:WidgetColorKey`.
    Deliberate per LessonsLearned (no cross-target imports), but worth
    flagging when the next color is added.

- **Unused or outdated files / symbols:**
  - `Task/Views/Settings/ManageTagsView.swift:140-143` —
    `private func delete(_ tag: TaskTag)` has no callers
    (`grep -rn "delete(_ tag" Task/` finds only the definition).
  - The `.swipeActions` block on lines 117-123 of the same file is
    effectively dead because the row is not in a `List` (see N6).

- **Overly complex files or functions:**
  - `Task/Views/Task/TaskDetailView.swift` (474 lines) — mixes layout,
    state, navigation, three child sheets, and save/delete logic. The
    date-sheet helpers could move to their own file.
  - `Task/Views/Settings/SettingsView.swift` (462 lines) — section
    builders, sheet routing, and import/export glue all in one place.
    Splitting the Data subsystem into a small `SettingsDataController`
    would help.
  - `Task/Services/DataImportExport.swift:111-249` —
    `importData(_:context:)` is one ~140-line function doing five
    distinct merge passes. Extracting `mergeGroups`, `mergeTags`,
    `mergeTasks` would make N5 simpler to fix without changing
    behavior.
  - `Task/Views/Settings/AboutSheets.swift` (440 lines) — many small
    sheets in one file. Acceptable today; will hurt as About content
    grows.

- **Naming inconsistencies:**
  - `colorKey` (the property) vs `colorKeyRaw` (the stored string) on
    `BoardGroup` and `TaskTag` — fine pattern, but the API exposes
    both, which can confuse contributors.
  - `BoardGroup.orderedTasks` (sortIndex order) vs
    `BoardGroup.sortedTasks(field:direction:)` (display order) —
    similar names, very different semantics. See N2 for the bug this
    enables.

- **Structural improvements:**
  - Centralize widget snapshot writing + reload behind a single helper
    (`UpcomingSnapshotBuilder.writeAndReload(from:)`) so N1 and the
    "missing snapshot write" callers (N3) cannot drift again.
  - Add an explicit `enum DragPayload { case task(UUID), group(UUID) }`
    with `init?(rawString:)` to replace the `"group:"`-prefix string
    parsing in `ColumnView.handleDrop`. Easier to extend (e.g. tag
    drag).

---

## 4. Functional issues

- **Board / columns / cards** — Pagination, `.id()` re-render on sort
  change, and pull-to-refresh all behave correctly. Drag-reorder has
  the silent-corruption issue called out in N2.
- **Drag and drop** — Within-column move math is sound on Manual sort.
  Cross-column path writes sortIndex correctly via `onReorder` but
  saves twice (N13) and depends on N2's mismatch.
- **Calendar picker** — Single and range modes work. Range mode after
  start+end are both set "resets to a new single-day selection" as
  documented; this is intentional but slightly hidden — users may
  initially expect a tap to extend the range. Worth a one-sentence
  hint in the picker sheet (Low priority).
- **Search** — Works correctly. `filteredTasks` is recomputed every
  body update over `board.tasks ?? []`; not a real bug at expected
  task counts.
- **Settings → Customization (Manage Groups, Manage Tags)** —
  Reordering groups via inline up/down arrows works. Manage Tags
  shows a swipe affordance that is non-functional (N6). New-tag /
  new-group flows reject empty names but silently no-op when a
  duplicate name is entered (the user sees nothing happen) — consider
  a one-line "Already exists" hint.
- **Import / Export / Reset** — Round-trips fine for self-exported
  data. Risks called out in N5 (orphaned references) and N9 (UI
  freeze on large data).
- **Notifications** — Schedule path is correct but doesn't guard
  against past dates (N8). Cancel paths are reliable: delete and
  reminder-off both go through `NotificationService.cancel(for:)`.
- **Widget snapshot** — `UpcomingSnapshotBuilder` filters to a 7-day
  window using `dueDate ?? workingEnd ?? workingStart`. Correct, but
  the snapshot is stale after group edits (N3) and after any change
  given no timeline reload (N1).
- **Localization** — `Localizable.xcstrings` covers the major user
  strings (Untitled, Empty, More, Notes, Reminder, Status, Tags,
  Manage Groups, Manage Tags, Task reminder, OK, etc.). Auto-extract
  on build will keep this current, but the file has only 68
  `zh-Hans` translation blocks against 1000+ lines of catalog —
  many user-visible strings still rely on the English source string
  for Chinese display. Worth a focused pass before the first
  Chinese-targeted release.

---

## 5. UI/UX issues

- **Card reminder icon** placement is wrong for due-only and dual-date
  tasks (N4).
- **iCloud Sync row** looks tappable but isn't (N10).
- **Sheet toolbars** are inconsistent (N11).
- **Manage Tags swipe** is a no-op and trains users that nothing
  happens (N6).
- **CalendarPicker range mode** — after start+end are set, tapping a
  non-endpoint silently resets to a new single-day selection. The
  state transition is correct per design but unexpected for users
  trying to extend the range. Consider a hint or an "Extend" toggle.
- **"More +N" button** — the `+N` value is `min(pageSize, hidden)`,
  so a column with 47 tasks shown 10 → "More +10" three times then
  "More +7" once. Reads fine; minor UX note that the badge is the
  next chunk size, not the remaining total. Consider showing both
  ("More +10 (37 left)").
- **iOS 26 fallback parity** — `BottomNavBar` forks via `#available
  (iOS 26.0, *)`; the iOS 18-25 path uses `.thinMaterial` with
  `secondarySystemBackground` circles and is feature-complete (search
  field, plus/settings/cancel buttons). No regressions vs the Glass
  variant. Confirmed via code read; cannot verify on-device.
- **Drag preview shapes** — `Capsule(style: .continuous)` for the
  group header and `RoundedRectangle(cornerRadius: 10)` for cards
  are applied via `.contentShape(.dragPreview, …)`. Correct per
  LessonsLearned.

---

## 6. Data and persistence issues

- **N5 (import orphans)** is the headline data risk.
- **N7 (in-memory fallback)** silently loses data when the persistent
  store fails to open.
- **`SharedDefaultsService.writeUpcoming` ignores encode failures**:
  the `if let data = try? JSONEncoder().encode(snapshot)` form means
  any encoding error is swallowed. In practice the snapshot is plain
  Codable types so failures are unlikely, but logging the error
  would help if it ever happens.
- **Cascade delete from `Board`** is wired correctly:
  `Board.groups`, `Board.tags`, `Board.tasks` all have
  `deleteRule: .cascade`. Reset path
  (`DataImportExport.resetAll(context:)`) deletes boards then
  re-seeds — correct, but it doesn't explicitly clear `task.tags`
  on every task before delete (relies on cascade). Worth a one-line
  comment noting why.
- **CloudKit-readiness invariants hold**: every `@Model` property in
  `Board.swift`, `BoardGroup.swift`, `TaskTag.swift`, `TaskItem.swift`
  has a default value, no `@Attribute(.unique)`, optional inverse
  relationships.
- **Export ordering**: `BoardExportPayload.tasks` are exported in
  whatever order `(board.tasks ?? [])` returns from SwiftData (not
  necessarily sortIndex). Round-trip still works since `sortIndex` is
  persisted, but exports are not byte-identical across runs. Low.

---

## 7. Configuration and platform issues

- **DEVELOPMENT_TEAM is hardcoded** to `U6KN3BQL72` in
  `task.xcodeproj/project.pbxproj` (lines 451, 488, 523, 552). Fine
  for personal but blocks contributors from a clean Archive without
  edits. Consider moving to a per-developer `.xcconfig` outside of
  `project.pbxproj`. Low.
- **iOS deployment target 18.0** in all four targets — matches
  README requirements.
- **App Group `group.com.ijustin.task`** is correctly configured on
  both `Task.entitlements` and `TaskWidgetExtension.entitlements`.
- **Alternate icons** registered via
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "Rose Violet
  Midnight Neutral Light"` matches `AppIconOption.alternateName`. Not
  verified — would require reading the asset catalog.
- **PrivacyInfo.xcprivacy** declares `NSPrivacyAccessedAPICategoryUserDefaults`
  with reason `CA92.1` (App Group sharing). Correct.
- **Synchronized folder exceptions** — `TaskWidgetExtension/Info.plist`
  is correctly excluded via `PBXFileSystemSynchronizedBuildFileExceptionSet`.
  Same not needed for the Task target (no plist on disk; uses
  `GENERATE_INFOPLIST_FILE`).
- **Portrait-only orientation** in
  `INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait`
  for both Task release & debug configurations. Matches the current
  UI which has not been laid out for landscape. Worth a "may be
  landscape later" note only.
- **`LSApplicationCategoryType = public.app-category.productivity`**
  set — App Store category-ready.
- **`TARGETED_DEVICE_FAMILY = 1`** (iPhone only). Matches design.
- **Test target lacks coverage of imports, merges, drag-reorder,
  snapshot encoding, and notification scheduling** (see §8).

---

## 8. Testing gaps

- **Highest-risk uncovered features:**
  - Import / export round-trip integrity, especially the name-based
    fallback for groups/tags and orphan handling (N5).
  - Drag-reorder math, both within-column and cross-column, in both
    Manual and non-Manual sort modes (N2).
  - SwiftData cascade deletes (Board → Groups → Tasks).
  - Notification scheduling: past-date handling (N8), 9 AM default,
    cancel-on-delete/reminder-off, re-schedule on import.
  - Snapshot encoding round-trip between
    `SharedDefaultsService.UpcomingSnapshot` and
    `WidgetUpcomingSnapshot`.
- **Suggested tests:**
  - `testImportRoundTrip()` — export then re-import, assert IDs,
    sortIndices, and tag membership all match the source.
  - `testImportNameMatchForGroups()` — seed default groups, import a
    file with same names but different IDs, assert no duplicates.
  - `testImportOrphanReferences()` — import a task whose `groupID`
    is missing from the payload and from existing data, assert it
    lands in a fallback group (per N5).
  - `testReorderWithinColumn()` — set up 5 tasks with manual
    sortIndex 0..4, reorder via `BoardView.reorder`, assert new
    sortIndex order.
  - `testReorderInTitleSortMode()` — set sortField to .title, perform
    a reorder, assert manual sortIndex is preserved (or that the API
    refuses the operation, per the N2 fix).
  - `testNotificationPastDateSkips()` — set a past due date, call
    `NotificationService.schedule`, assert no pending request via
    `UNUserNotificationCenter.current().getPendingNotificationRequests`.
    Requires test-host entitlements.
  - `testSnapshotEncodingMatchesWidgetDecoder()` — encode an
    `UpcomingSnapshotEntry`, decode as `WidgetUpcomingEntry`, assert
    field-by-field equality.
- **Manual / device-only:**
  - Verify widget refreshes promptly after task edits once N1 is fixed
    (real device, real widget install).
  - Verify alternate app icon transitions on iOS 18 vs 26.
  - VoiceOver pass over `BottomNavBar`, `BoardView`, `TaskDetailView`.

---

## 9. Priority recommendations

- **Fix first:**
  - **N1** — One-line fix; restores expected widget behavior. Call
    `WidgetCenter.shared.reloadAllTimelines()` inside
    `UpcomingSnapshotBuilder.writeSnapshot`.
  - **N3** — Add `UpcomingSnapshotBuilder.writeSnapshot` to
    `GroupMenuSheet.save` and `deleteAndDismiss` (depends on N1's
    refactor for free).
  - **N2** — Disable card drag-reorder in non-Manual sort modes (or
    align indices). High user impact, modest code change.
  - **N4** — Move reminder icon to the date row that matches
    `primaryReminderDate`. Small UI change, prevents misleading
    affordance.
- **Fix next:**
  - **N5** — Add a fallback group for orphaned task imports; consider
    surfacing dropped-reference counts in the success alert.
  - **N6** — Replace the no-op swipe with a real trailing button, or
    rebuild the tag list inside `List` so the swipe gesture binds.
  - **N7** — Surface the in-memory fallback to the user; consider
    quarantining the failed store file.
  - **N8** — Skip notifications for past dates and (optionally) show
    a hint in `TaskDetailView`.
  - **N9** — Yield inside import/reset loops or move to a background
    `ModelContext`.
- **Optional cleanup:**
  - **N10** — Dim or properly affordance the iCloud Sync row.
  - **N11** — Pick a sheet-toolbar rule and apply it uniformly.
  - **N12** — Drop or annotate the README's `Task/Info.plist` entry.
  - **N13** — Collapse cross-column drop into a single transactional
    helper.
  - **N14** — Extract `Bundle.main` version/build helpers.
  - **N15** — Standardize JSON Date encoding strategy across snapshot
    and export.

---

## What was checked

- `README.md`, `VersionHistory.md`, `LessonsLearned.md` end-to-end.
- All Swift source files under `Task/` (models, services, view
  models, all views in Board / Task / Search / Settings,
  Components, Utils, TaskApp).
- All Swift source files under `TaskWidgetExtension/`.
- `Task/Task.entitlements`, `TaskWidgetExtension.entitlements`,
  `Task/PrivacyInfo.xcprivacy`, `TaskWidgetExtension/Info.plist`.
- `task.xcodeproj/project.pbxproj` — build settings (deployment
  target, marketing/current version, INFOPLIST keys, bundle IDs,
  code signing, asset catalog config), synchronized folder
  exceptions, embed-extensions phase.
- `Task/Localizable.xcstrings` — spot checks for key user-facing
  strings (Untitled, Empty, More, Notes, Reminder, Status, Tags,
  Manage Groups, Manage Tags, Task reminder, OK, alert copy).
- `TaskTests/TaskTests.swift`.
- Grep queries: `WidgetCenter|reloadAllTimelines|reloadTimelines`,
  `UpcomingSnapshotBuilder.writeSnapshot`, `\.swipeActions`,
  `private func delete`, `String(localized:`, `Text("...")` for
  unlocalized literals, `INFOPLIST_KEY_*`, `PRODUCT_BUNDLE_IDENTIFIER`,
  `IPHONEOS_DEPLOYMENT_TARGET`, `ASSETCATALOG_COMPILER_*`.

## Not checked (worth a follow-up)

- Actual runtime behavior on iOS 18.x vs iOS 26 devices /
  simulators (Liquid Glass parity, alternate icon transitions,
  drag previews, ProgressOverlay animation under @MainActor work).
- On-device notification delivery and authorization-denied paths.
- Instruments / memory profile (board with thousands of tasks).
- Widget rendering under each `WidgetFamily`; widget reload
  cadence after N1 is fixed.
- Asset catalog contents (whether
  `Rose/Violet/Midnight/Neutral/Light` and `ClassicPreview` etc.
  asset names actually exist; `INCLUDE_ALL_APPICON_ASSETS = YES`
  is set but the catalog is not part of this audit).
- Full pass of `Localizable.xcstrings` for missing `zh-Hans`
  translations against every emitted key.
- Accessibility audit (Dynamic Type, VoiceOver labels, hit
  targets).
- No prior `docs/IssuesArchive-*.md` archives exist — nothing to
  cross-reference, so every entry in this report is net-new.
